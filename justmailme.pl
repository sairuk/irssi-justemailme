use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use POSIX;

$VERSION = '0.0.2';
%IRSSI = (
    authors     => 'sairuk',
    contact     => '@sairukau',
    name        => 'justmailme',
    description => 'Mail out messages from irssi use /usr/bin/mail',
    url         => '',
    license     => 'GNU General Public License',
    changed     => '$Date: 2007-01-13 12:00:00 +0100 (Sun, 25 Sep 2016) $'
    );

## based on https://github.com/kintoandar/shell_scripts/blob/master/plugins/fnotify.pl

# Please set the variables (don't forget to escape "\" the "@" symbol like the example)
my $EMAIL = "";                                 # string string
my $SSMTP = "/bin/mail";                        # path to mail
my @IGNORE = ("");                              # array of channels, nicks
my $INTERVAL = "300";                           # check time in seconds
my $DEBUG = 0;                                  # booleen set debug mode on/off 


# Required
my @MSGS = ();
my $OUTPUTMODE = "Mail";
my $OPMODE = "NORMAL";

if ($DEBUG) {
    $OPMODE = "DEBUG";
    $INTERVAL = 5;
    $OUTPUTMODE = 'Screen';
}

Irssi::print($OPMODE . ' mode active');
Irssi::print('Output: '. $OUTPUTMODE);
Irssi::print('Interval: '. $INTERVAL);

# Private message parsing
sub priv_msg {
    my ($server,$msg,$nick,$address,$target) = @_;
    formatmessage($nick, "PRIVATE MESSAGE from " . $nick, $server->{tag});
}

# Printing hilight's
sub hilight {
    my ($dest, $text, $stripped) = @_;
    if ($dest->{level} & MSGLEVEL_HILIGHT) {
        formatmessage($dest->{target}, 'MENTION in ' . $dest->{target},  $dest->{server}->{tag});
    }
}


sub formatmessage {
    my ($criteria, $msg, $server) = @_;
    checkignore($criteria, $msg . " [" . $server . "]");
}

sub checkignore {
    my ($check, $msg) = @_;
    if ( /$check/i ~~ @IGNORE) {
        if ( $DEBUG ) {
            Irssi::print($check . " is on the ignore list");
        }
    } else {
        push(@MSGS,$msg);
    }
}

sub checkmail {
    if (scalar(@MSGS) == 0) {
        return undef;  
    }
    justmailme(@MSGS);
    @MSGS = ();
}


# Send the Mail
sub justmailme {
    my ($msg) = @_;
    if ( $DEBUG ) {
        Irssi::print($msg);
    } else {
        my $output = $SSMTP ." -s \"[IRSSI New Notification]\" ". $EMAIL;
        my $mail = `echo " \""$msg"\"" | $output`;
    }
}

Irssi::timeout_add($INTERVAL*1000, 'checkmail', '');
Irssi::signal_add_last("message private", "priv_msg");
Irssi::signal_add_last("print text", "hilight"); 
