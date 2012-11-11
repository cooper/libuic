# Copyright (c) 2012, Mitchell Cooper
# UIC: manages servers, users, and channels on a UIC network or server.
# performs tasks that do not fall under the subcategories of server, user, connection, or channel.
package UIC;

use warnings;
use strict;
use utf8;
use feature qw(say switch);
use parent 'UIC::EventedObject';

use UIC::EventedObject;
use UIC::Server;
use UIC::User;
use UIC::Channel;
use UIC::Parser;

use Scalar::Util 'looks_like_number';

sub parse_data {
    my ($uic, $data) = @_;
    # blah blah, call handlers.
}

# register a command handler.
# $uic->register_handler('someCommand', {
#     someParameter => 'number',  # an integer or decimal
#     someOther     => 'string',  # a plain old string
#     anotherParam  => 'user',    # a user ID
#     evenMoreParam => 'server',  # a server ID
#     yetAnother    => 'channel', # a channel ID
#     evenAnother   => 'bool'
# }, \&myHandler, 200);
# returns a handler identifier.
sub register_handler {
    my ($uic, $command, $parameters, $callback, $priority) = @_;                    say("registering $command");
    $priority ||= 0;
    
    # make sure callback is CODE and parameters is HASH.
    return if !ref $callback   || ref $callback ne 'CODE';                          say("got past CODE");
    return if !ref $parameters || ref $parameters ne 'HASH';                        say("got past HASH");
    
    # make sure the types are valid.
    my @valid = qw(number string user server channel);
    foreach my $parameter (keys %$parameters) {
        return if !($parameter ~~ @valid);
    }                                                                               say("got past valid");
    
    # store the handler.
    $uic->{handlers}{$command}{$priority} ||= [];
    push @{$uic->{handlers}{$command}{$priority}}, {
        command    => $command,
        callback   => $callback,
        parameters => $parameters,
        priority   => $priority
    };                                                                              say("registered it");
    
    return defined $uic->{handlerID} ? ++$uic->{handlerID} : ($uic->{handlerID} = 0);
}

# fire a command's handlers.
# $uic->fire_handler('someCommand', {
#     someParameter => '0',
#     someOther     => 'hello!'
# });
sub fire_handler {
    my ($uic, $command, $parameters) = @_;
                                                                                    say("firing handler $command");
    # no handlers for this command.
    return unless $uic->{handlers}{$command};                                       say("got past return");
    
    # call each handler.
    my $return = {};
    foreach my $priority (sort { $b <=> $a } keys %{$uic->{handlers}{$command}}) {  say("priority $priority");
    foreach my $h (@{$uic->{handlers}{$command}{$priority}}) {                      say("h: $$h{command}");
    
        # process parameter types.
        my %final_params;
        foreach my $parameter (keys %{$h->{parameters}}) {                          say("parameter: $parameter");
            $final_params{$parameter} = $uic->interpret_string_as($h->{parameters}{$parameter}, $parameters->{$parameter})
            if exists $parameters->{$parameter};
        }
        
        # create information object.
        my %info = (
            caller   => [caller 1],
            command  => $command,
            priority => $priority
        );
        
        # call it.
        $h->{callback}(\%final_params, $return, \%info);
        
    }}
}

# UIC type conversions. true hackery.
sub interpret_string_as {
    my ($uic, $type, $string) = @_;
    given ($type) {

        # string - append an empty string.
        when ('string') {
            return $string.q();
        }
        
        # number - add a zero.
        when ('number') {
            if (looks_like_number($string)) {
                return $string + 0;
            }
            return 1;
        }
        
        # bool - double opposite.
        when ('bool') {
            return !!$string;
        }
        
        # user - lookup a user object.
        when ('user') {
        }
        
        # channel - lookup a channel object.
        when ('channel') {
        }
        
        # server - lookup a server object.
        when ('server') {
        }
        
    }
    return;
}

# handler($parameters, $return, $info)

1
