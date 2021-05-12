#!/usr/bin/perl
######################################################################
# killcx :
#
# Close a TCP connection under Linux.
#
# (c) Jerome Bruandet - <floodmon@spamcleaner.org>
#
# version 1.0.3 - 18-May-2011
#
# doc : http://killcx.sourceforge.net/
#
######################################################################
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
######################################################################

use strict;
use Socket;
use Net::RawIP;
use Net::Pcap;
use NetPacket::Ethernet qw(:strip);
use NetPacket::IP qw(:strip);
use NetPacket::TCP;
use POSIX qw(setsid);

my $appname = 'killcx';
my $version = 'v1.0.3';
my $copyright = '(c)2009-2011 Jerome Bruandet - http://killcx.sourceforge.net/';

print "$appname $version - $copyright\n\n";
if ( $> ) {
   print "\t[ERROR] : you must be root\n\n";
   exit 1;
} elsif ( $^O ne 'linux' ){
   print "\t[ERROR] : that script is for Linux only, not $^O\n\n";
   exit 1;
}
$SIG{USR1} = \&check_res;

my ( $dest_ip, $dest_port ) =
   $ARGV[0] =~ /^(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}):(\d+)$/;
my $interface = $ARGV[1];

if ( ( ! $dest_ip ) || ( ! $dest_port ) ) {
print "- syntax   : $appname <destip:destport> <interface>

  destip               : remote IP
  destport             : remote port
  interface (optional) : network interface (eth0, lo etc). Note that
                         in many cases, using 'lo' (loopback) will give
                         better results, specially when a connection
                         is not yet or no longer in the ESTABLISHED state
                         (SYN_RECV, TIME_WAIT etc).

- example  : $appname 10.11.12.13:1234
             $appname 10.11.12.13:1234 eth0

- doc      :  http://killcx.sourceforge.net/

";
   exit 1;
}

my $pid = $$;

my %TCP_STATES = (
'01' => 'ESTABLISHED', '02' => 'SYN_SENT',  '03' => 'SYN_RECV',
'04' => 'FIN_WAIT1',   '05' => 'FIN_WAIT2', '06' => 'TIME_WAIT',
'07' => 'CLOSE',       '08' => 'CLOSE_WAIT','09' => 'LAST_ACK',
'0A' => 'LISTEN',      '0B' => 'CLOSING'
);

# convert to network byte order :
$dest_ip =~ /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
my $dest_hex = sprintf "%.2X%.2X%.2X%.2X:%.4X",$4,$3,$2,$1,$dest_port;
# check in /proc/net/tcp :
print "[PARENT] checking connection with [$dest_ip:$dest_port]\n";
my ( $local_ip, $local_port, $state) = &check_tcp( $dest_hex );
if ( ! $state ) {
   print "[PARENT] error : unable to find a connection with ".
      "[$dest_ip:$dest_port]\n\n";
   exit 1;
}

print "[PARENT] found connection with [$local_ip:$local_port] ".
   "($TCP_STATES{$state})\n";

# fork our child which will hook the server response to our spoofed
# packet and extract the correct acknum (and seqnum) needed to close
# the connection :
print "[PARENT] forking child\n";
use POSIX 'WNOHANG';
$SIG{CHLD} = sub { while( waitpid( -1,WNOHANG ) > 0 ) {} };
defined ( my $child_pid = fork ) or
   die "[PARENT] error : cannot fork : $!\n";
if ( $child_pid == 0 ) {
   setsid or die "[CHILD]  error : cannot setid : $!";
   my ($err, $filter, $netmask, $address, $pcap);

   # no interface given, let's try to find one :
   if ( ! $interface ) {
      $interface = Net::Pcap::lookupdev( \$err );
      print "[CHILD]  ";
      if ( $interface ) {
         print "interface not defined, will use [$interface]\n";
      } else {
         # switch to loopback if we can't find any interface :
         print "no interface found, switching to loopback\n";
         $interface = 'lo';
      }
   }
   # let's sniff :
   print "[CHILD]  setting up filter to sniff ACK on [$interface]".
      " for 5 seconds\n";
   my $pcap = Net::Pcap::open_live( $interface, 100, 1, 5000, \$err) ||
      die "[CHILD]  error : open_live failed : $err\n";
   # setup filter :
   Net::Pcap::compile( $pcap, \$filter,
      "(dst port $dest_port) && (src port $local_port)",
      0, $netmask) &&
      die "[CHILD]  error : compile failed : $!\n";
   Net::Pcap::setfilter($pcap, $filter) &&
      die "[CHILD]  error : setfilter failed : $!\n";
   # only want to hook 1 packet :
   Net::Pcap::loop($pcap, 1 , \&process_packet, '');
   Net::Pcap::close($pcap);
   # all done, let's inform our parent :
   print "[CHILD]  all done, sending USR1 signal to parent [$pid] ".
      "and exiting\n";
   `kill -s USR1 $pid`;
   exit 0;
}

# wait 0.5 second for our child to be ready :
select( undef, undef, undef, 0.5 );
print "[PARENT] sending spoofed SYN to [$local_ip:$local_port]".
   " with bogus SeqNum\n";

# send spoofed SYN packet :
my $packet = Net::RawIP->new({
      ip => {  frag_off => 0, tos => 0,
               saddr => $dest_ip, daddr => $local_ip
            },
      tcp =>{  dest => $local_port, source => $dest_port,
               seq => 10, syn => 1
            }
   });
   $packet->send;

# wait max 5 seconds :
select( undef, undef, undef, 5 );

# didn't receive any signal from our child, it has probably failed :
print "[PARENT] no response from child, operation may have failed\n";
if ( $interface ne 'lo' ) {
   print "[PARENT] => you may try using 'lo' as interface parameter\n";
}
print "[PARENT] killing child [$child_pid] and exiting program\n\n";
# kill it and exit :
kill 9, $child_pid;

exit 1;

######################################################################

sub check_res {

   # received signal from our child :
   print "[PARENT] received child signal, checking results...\n";
   # check whether the operation was successful or not :
   ( $local_ip, $local_port, $state) = &check_tcp( $dest_hex );
   if ( $state ) {
   print "         => error : connection hasn't been closed\n\n";
      exit 1;
   }
   print "         => success : connection has been closed !\n\n";
   exit 0;

}

######################################################################

sub process_packet {

   my( $user_data, $header, $packet ) = @_;
   my $ether_data = NetPacket::Ethernet::strip($packet);

   # decode TCP/IP packet (server response to our spoofed packet) :
   my $ip = NetPacket::IP->decode($ether_data);
   my $tcp = NetPacket::TCP->decode($ip->{'data'});

   print "[CHILD]  hooked ACK from [$local_ip:$local_port]\n";
   # look for the magic acknum :
   print "[CHILD]  ";
   if ( $tcp->{acknum} ) {
      print "found AckNum [$tcp->{acknum}] and SeqNum ".
         "[$tcp->{seqnum}]\n";
      print "[CHILD]  sending spoofed RST to [$local_ip:$local_port]".
         " with SeqNum [$tcp->{acknum}]\n";
      # we have it : spoof another packet (RST) with the correct seqnum
      # to close the connection :
      my $packet = Net::RawIP->new( {
         ip => {  frag_off => 0, tos => 0,
                  saddr => $dest_ip, daddr => $local_ip
               },
         tcp =>{  dest => $local_port, source => $dest_port,
                  seq => $tcp->{acknum}, rst => 1
               }
      } );
         $packet->send;

      # if the connection was in the ESTABLISHED state we close it
      # with the remote host as well, otherwise we don't care
      # (the server would reply with a RST packet anyway) :
      if ( $state == 1 ) {
         print "[CHILD]  sending RST ".
            "to remote host as well with SeqNum [$tcp->{seqnum}]\n";
         my $packet = Net::RawIP->new( {
         ip => {  frag_off => 0, tos => 0,
                  saddr => $local_ip, daddr => $dest_ip
               },
         tcp =>{  dest => $dest_port, source => $local_port,
                  seq => $tcp->{seqnum}, rst => 1
               }
         } );
         $packet->send;
      }
   } else {
      # very unlikely to happen (ACK packets always have acknum) :
      print "error : no AckNum found in packet\n";
      exit 1;
   }
}

######################################################################

sub check_tcp {

   my $hex_rem = shift;
   my ( $li, $lp, $st );
   open TCP, "</proc/net/tcp";
   while ( <TCP> ) {
      if ( /^\s*\d+:\s+(.{8}):(.{4})\s+$hex_rem\s+(.{2})\s/ ) {
         $st = $3;
         $lp = hex( $2 );
         ($li) = $1 =~ /(.{2})(.{2})(.{2})(.{2})/;
         $li = inet_ntoa( pack("N", hex( $4.$3.$2.$1 ) ) );
         last;
      }
   }
   close TCP;
   # if not found, check /proc/net/tcp6 :
   if ( ( ! $st ) && ( -e '/proc/net/tcp6' ) ) {
      open TCP, "</proc/net/tcp6";
      while ( <TCP> ) {
         if ( /^\s*\d+:\s+\d{16}FFFF0000(.{8}):(.{4})\s+
               \d{16}FFFF0000$hex_rem\s+(.{2})\s/x ) {
            $st = $3;
            $lp = hex( $2 );
            ($li) = $1 =~ /(.{2})(.{2})(.{2})(.{2})/;
            $li = inet_ntoa( pack("N", hex( $4.$3.$2.$1 ) ) );
            last;
         }
      }
      close TCP;
   }
   return ( $li, $lp, $st );

}

######################################################################
# EOF
