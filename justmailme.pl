use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use POSIX;
use Data::Dumper;

$VERSION = '0.1.5';
%IRSSI = (
    authors     => 'sairuk',
    contact     => '@sairukau',
    name        => 'justmailme',
    description => 'Mail out messages from irssi use /usr/bin/mail',
    url         => '',
    license     => 'GNU General Public License',
    changed     => '$Date: 2018-06-22 12:00:00 +0100 (Fri, 22 Jun 2018) $'
    );

## based on https://github.com/kintoandar/shell_scripts/blob/master/plugins/fnotify.pl
my %options;

sub read_settings {
    # Please set the variables (don't forget to escape "\" the "@" symbol like the example)
    %options = (
        email    => Irssi::settings_get_str('justmailme_email'),
        mailer   => Irssi::settings_get_str('justmailme_mailer'),
        ignore   => [split(";",Irssi::settings_get_str('justmailme_ignore'))],
        interval => Irssi::settings_get_int('justmailme_interval'),
        jmmlog   => Irssi::settings_get_str('justmailme_log'),
        msgbody  => Irssi::settings_get_bool('justmailme_msgbody'),
        logging  => Irssi::settings_get_bool('justmailme_logging'),
        debug    => Irssi::settings_get_bool('justmailme_debug'),
    );
}


my %msg_queue = ();
sub _log {
    if ( $options{logging} ) {
        open(my $LOGFILE, ">> $options{jmmlog}") or die("Couldn't open logfile");
        print $LOGFILE Dumper(@_);   
        if ( $options{debug} ) { Irssi::print("@_"); }
    }
}

# Private message parsing
sub priv_msg {
    my ($server, $text, $from) = @_;
    _log "[PRVMSG] Dest nick: $server->{nick}";
    _log "[PRVMSG] Server Tag: $server->{tag}";
    my $send_msg = "PRIVATE MESSAGE from " . $from . " [ " . $server->{tag} . " ]";
    if ( checkaway($server) && ! checkignore($from)) {
        if ( $options{msgbody} ) {
            $send_msg .= "\n - $text";
        }
        _log "[PRVMSG] $send_msg";
        push(@{$msg_queue{$from}},$send_msg);
    }
}

# Printing hilight's
sub hilight {
    my ($dest, $text, $msg) = @_;
    if ($dest->{level} & MSGLEVEL_HILIGHT) {
        _log "[HIGHLIGHT] Target: $dest->{target}";
        _log "[HIGHLIGHT] Level: $dest->{level}";
        _log "[HIGHLIGHT] Server: $dest->{server}";
        if ( checkaway($dest->{server}) && ! checkignore($dest->{target})) {
            my $send_msg = "MENTION in $dest->{target}";
            if ( $options{msgbody} ) {
                $send_msg .= "\n - $text";
            }
            _log "[HIGHLIGHT] $send_msg";
            $send_msg = strip_codes($send_msg);
            push(@{$msg_queue{$dest->{target}}}, $send_msg);
        }
    }
}

sub strip_codes {
    my ($string) = @_;
    _log "[STRIPCODES] $string";
    $string =~ s/[^\x0A\x0D\x20-\x7F\x80]//g;   
    _log "[STRIPCODES] $string";
    _log "[STRIPHEX] " . unpack "H*", $string;
    return $string;
}

sub checkignore {
    my ($check) = @_;
    my @IGNORE = $options{ignore};
    my $log_msg = "[CHECKIGNORE] $check";
    my $result = /$check/i ~~ $options{ignore};
    
    if ( $result ) {
        _log "$log_msg is ignored";
    } else {
        _log "$log_msg is OK, adding to message queue";
    }
    return $result;
}

sub checkaway {
    my ($server) = @_;
    if ( $options{debug} ) { $server->{usermode_away} = 1 };
    _log "[CHECKAWAY} $server->{usermode_away}";
    return $server->{usermode_away};
}

sub checkqueue {
    Irssi::print("Messages in Queue: " . queue_size());
}

sub checkmail {
    my $queue_size = queue_size();
    _log "[CHECKMAIL] Messages in Queue: $queue_size";
    if ( ! $queue_size ) { return undef; }
    justmailme(\%msg_queue);
}

sub build_msg {
    my $msg_str = "==[ MESSAGE SUMMARY ]==\n";
    foreach my $from ( keys %msg_queue ) {
        $msg_str .= "\n\n";
        foreach my $msg_line ( @{$msg_queue{$from}} ) {
            $msg_str .= join "\n", $msg_line, "\n";
        }
    }
    return $msg_str;
}

sub queue_size {
   return scalar(values %msg_queue);    
}


# Send the Mail
sub justmailme {
    my $msg = build_msg;
    if ($options{debug}) {
        _log "[BUILDMSG]\n$msg";
    } else {
        _log "[MAILSEND] Sending Mail";
        if ( $options{mailer} & $options{email} ) {
            my $output = $options{mailer} ." -s \"[IRSSI New Notification]\nContent-Type: text/plain; charset=UTF-8\" ". $options{email};
            my $mail = `echo " \""$msg"\"" | $output`;
            %msg_queue = ();
        } else {
            _log "[JUSTMAILME], mailer and/or email options are not configured";
        }
    }
}

sub init {
    #%options = read_settings();
    read_settings();
    if ($options{debug}) {
       $options{interval} = 5;
       Irssi::print('DEBUG mode active');
       Irssi::print('Output: Screen');
       Irssi::print('Interval: '. $options{interval});
    }
    Irssi::timeout_add($options{interval}*1000, 'checkmail', '');
}


Irssi::signal_add('setup changed', \&read_settings);
Irssi::signal_add_last("message private",\&priv_msg);
Irssi::signal_add_last("print text", \&hilight); 

Irssi::command_bind('jmm_check',\&checkqueue);

Irssi::settings_add_str('justmailme', 'justmailme_email', '');
Irssi::settings_add_str('justmailme', 'justmailme_mailer', '/bin/mail');
Irssi::settings_add_bool('justmailme', 'justmailme_msgbody', 0);
Irssi::settings_add_str('justmailme', 'justmailme_ignore', '');
Irssi::settings_add_int('justmailme', 'justmailme_interval', 300);
Irssi::settings_add_str('justmailme', 'justmailme_log', Irssi::get_irssi_dir . '/justmailme.log');
Irssi::settings_add_bool('justmailme', 'justmailme_logging', 1);
Irssi::settings_add_bool('justmailme', 'justmailme_debug', 0);

init();
