package Panfish::Logger;

use strict;
use English;
use warnings;
use Config;

use Panfish::ForkExecutor;

# 
# Creates a new instance of Logger
#
#
sub new {
    my $class = shift;
    my $self = {
        OUT                 => undef,
	OutputTime          => 1,
        DEBUG               => "DEBUG",
        WARN                => "WARN",
        ERROR               => "ERROR",
        FATAL               => "FATAL",
        Level               => undef,
        NotificationLevel   => undef,
        NotificationSubject => "Panfish Log Message",
        Email               => undef,
	LogFile             => undef
    };
    $self->{Level} = $self->{DEBUG};
    $self->{NotificationLevel} = $self->{ERROR}.",".$self->{FATAL};

    return bless ($self,$class);
}

sub setLevelBasedOnVerbosity {
    my $self = shift;
    my $verbosity = shift;
    if (!defined($verbosity)){
        $self->setLevel($self->{ERROR});
    }
    else {

        if ($verbosity == 1){
            $self->setLevel($self->{WARN});
        } elsif ($verbosity == 2){
            $self->setLevel($self->{INFO});
        } elsif ($verbosity == 3){
            $self->setLevel($self->{DEBUG});
    }
}


}

sub setNotificationSubject {
    my $self = shift;
    $self->{NotificationSubject} = shift;
}
sub getNotificationSubject {
    my $self = shift;
    return $self->{NotificationSubject};
}

sub setNotificationEmail {
    my $self = shift;
    $self->{Email} = shift;
}

sub getNotificationEmail {
    my $self = shift;
    return $self->{Email};
}


sub setNotificationLevel {
    my $self = shift;
    $self->{NotificationLevel} = shift;
}

sub getNotificationLevel {
    my $self = shift;
    return $self->{NotificationLevel};
}




#
#
#
sub setLevel {
    my $self = shift;
    $self->{Level} = shift;
}

#
# Calling this method disables the output of time stamp
#
sub disableTimeOutput {
    my $self = shift;
    $self->{OutputTime} = 0;
}

#
# Calling this method enables the output of time stamp
#
sub enableTimeOutput {
    my $self = shift;
    $self->{OutputTime} = 1;
}


#
# Calling this method sets the output for logger to use
# the LogFile is also set to undefined
#
sub setOutput {
    my $self = shift;
    $self->{OUT} = shift;
    $self->{LogFile} = undef;
}

#
# If the logfile was opened internally then this will close
# the logfile
#
sub closeLog {
    my $self = shift;
    if (defined($self->{OUT}) && defined($self->{LogFile})){
	close($self->{OUT});
    }
}

#
# Gets full path to logfile if created internally like when
# createBirnccLog method is called
#
sub getLogFile {
    my $self = shift;
    return $self->{LogFile};
}

#
# Log info message
#
sub info {
    my $self = shift;
    my $message = shift;
    $self->_logmessage("INFO",$message);

}

#
# Log debug message
#
sub debug {
    my $self = shift;
    my $message = shift;
    $self->_logmessage("DEBUG",$message);
}

#
#
#
#
# Log warn message
#
sub warn{
    my $self = shift;
    my $message = shift;
    $self->_logmessage("WARN",$message);
}

#
# Log error message
#
sub error {
    my $self = shift;
    my $message = shift;
    $self->_logmessage("ERROR",$message);
}

#
# Log fatal message
#
sub fatal {
    my $self = shift;
    my $message = shift;
    $self->_logmessage("FATAL",$message);
}

#
# private method that actually performs the logging
# note if {OUT} is not set the log is sent to stdout
#
sub _logmessage {
    my $self = shift;
    my $level = shift;
    my $message = shift;

    if (defined($self->{Level})){
        if ($self->{Level} eq "INFO" &&
            $level eq "DEBUG"){
            return;
        }
        if ($self->{Level} eq "WARN" && 
            ($level eq "DEBUG" || $level eq "INFO")){
            return;
        }
        if ($self->{Level} eq "ERROR" && 
            ($level eq "DEBUG" || $level eq "INFO" ||
              $level eq "WARN")){
            return;
        }
        if ($self->{Level} eq "FATAL" &&
            ($level eq "DEBUG" || $level eq "INFO" ||
              $level eq "WARN"  || $level eq "ERROR")){
            return;
        }
    }

    if (!defined($message)){
        $message = "";
    }

    my $curtime = "";
    if ($self->{OutputTime} == 1){
	$curtime = localtime();
    }

    my ($package,$filename,$line) = caller(1);

    my $logmessage = $curtime." ".$level." [$package:$line] ".$message."\n";

    if (!defined($self->{OUT})){
	print $logmessage;
    }
    else {
	print {$self->{OUT}} $logmessage;
    }
    

    #if type is in notificationlevel then send email
    if (defined($self->{NotificationLevel}) &&
        $self->{NotificationLevel}=~/$level/){
        $self->_sendNotificationEmail($logmessage);
    }

    return;
}

sub _sendNotificationEmail {
    my $self = shift;
    my $message = shift;

    #bail if we have no message or no destination email address
    if (!defined($message) ||
        !defined($self->{Email}) ||
        !defined($self->{NotificationSubject})){
        return;
    }

    #verify the email contains an email address sort of
    if ($self->{Email}!~/^.*\@.*/){
        return;
    }

    if (open(SENDMAIL,"|/usr/sbin/sendmail -t")){
        print SENDMAIL "Reply-to: panfish\n";
        print SENDMAIL "Subject: ".$self->{NotificationSubject}."\n";
        print SENDMAIL "To: ".$self->{Email}."\n";
        print SENDMAIL "From: panfish\n";
        print SENDMAIL "Content-type: text/plain\n\n";
        print SENDMAIL $message;
        close(SENDMAIL);
    }
}


1; 

__END__
