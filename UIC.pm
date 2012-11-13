# Copyright (c) 2012, Mitchell Cooper
# UIC: manages servers, users, and channels on a UIC network or server.
# performs tasks that do not fall under the subcategories of server, user, connection, or channel.
package UIC;

use warnings;
use strict;
use utf8;
use feature qw(switch);
use parent 'UIC::EventedObject';

use UIC::EventedObject;
use UIC::Server;
use UIC::User;
use UIC::Channel;
use UIC::Parser;

use Scalar::Util qw(looks_like_number blessed);

###############
### LOGGING ###
###############

sub log {
}

######################
### HANDLING DATA ####
######################

sub parse_data {
    my ($uic, $data) = @_;
    # blah blah, call handlers.
}

#######################
### MESSAGE RETURNS ###
#######################

# store a callback for when return is received.
sub register_return_handler {
    my ($uic, $id, $callback) = @_;
    return unless ref $callback eq 'CODE';  
    $uic->{return_callback}{$id} ||= [];
    push @{$uic->{return_callback}{$id}}, $callback;
}

# fire a return callback.
sub fire_return {
    my ($uic, $id, $parameters, $info) = @_;
    return unless $uic->{return_callback}{$id};
    $_->($parameters, $info) foreach @{$uic->{return_callback}{$id}};
    delete $uic->{return_callback}{$id} if $uic->{return_callback}{$id};
}

#################################
### MANAGING COMMAND HANDLERS ###
#################################

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
    my ($uic, $command, $parameters, $callback, $priority, $package) = @_;
    $priority ||= 0;
    $package  ||= (caller)[0];
    
    # make sure callback is CODE and parameters is HASH.
    $uic->log('callback is not a CODE reference.')
    and return if !ref $callback   || ref $callback   ne 'CODE';
    $uic->log('parameters is not a HASH reference.')
    and return if !ref $parameters || ref $parameters ne 'HASH';
    
    # make sure the types are valid.
    my @valid = qw(number bool string user server channel);
    foreach my $parameter (keys %$parameters) {
        $uic->log("invalid type '$$parameters{$parameter}'")
        and return unless scalar grep { $_ eq $parameters->{$parameter} } @valid;
    }
    
    # generate an identifier.
    my $id = defined $uic->{handlerID} ? ++$uic->{handlerID} : ($uic->{handlerID} = 0);
    
    # store the handler.
    $uic->{handlers}{$command}{$priority} ||= [];
    push @{$uic->{handlers}{$command}{$priority}}, {
        command    => $command,
        callback   => $callback,
        parameters => $parameters,
        priority   => $priority,
        package    => $package,
        id         => $id    
    };
    
    $uic->log("registered handler $id for '$command' command to package $package");
    
    return $id;
}

# fire a command's handlers.
# $uic->fire_handler('someCommand', {
#     someParameter => '0',
#     someOther     => 'hello!'
# });
sub fire_handler {
    my ($uic, $command, $parameters, $info_sub) = @_;

    # no handlers for this command.
    return unless $uic->{handlers}{$command};
    
    # call each handler.
    my $return = {};
    foreach my $priority (sort { $b <=> $a } keys %{$uic->{handlers}{$command}}) {
    foreach my $h (@{$uic->{handlers}{$command}{$priority}}) {
    

        my %final_params;
        
        # handler accepts all parameters.
        if ($h->{parameters} eq 'all') {
            %final_params = %$parameters;
        }
        
        # process parameters.
        else {
            foreach my $parameter (keys %{$h->{parameters}}) {
                $final_params{$parameter} =
               $uic->interpret_string_as($h->{parameters}{$parameter}, $parameters->{$parameter})
             if exists $parameters->{$parameter};
            }
        }
        
        # create information object.
        my %info = (
            caller   => [caller 1],
            command  => $command,
            priority => $priority
        );
        
        # call info sub.
        $info_sub->(\%info);
        
        # call it.
        $h->{callback}(\%final_params, $return, \%info);
        
    }}
}

############################
### UIC TYPE CONVERSIONS ###
############################

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

###################
### SUBCLASSING ###
###################

# finds a subclass of the object.
# if $uic is of UIC class, $uic->subclass('User')
# will return "UIC::Server".
# if it is of subclass blah, "blah::Server".
# 
# using ->subclass makes it easy for UIC itself to
# be subclassed without requiring the subclass to
# implement every object creation method in UIC.
sub subclass {
    my ($uic, $subclass) = @_;
    my $class = blessed($uic);
    return "${class}::${subclass}";
}

########################
### MANAGING SERVERS ###
########################

# create a server and associate it with this UIC object.
sub new_server {
    my ($uic, %opts) = @_;
    my $server = $uic->subclass('Server')->new(%opts);
    $uic->set_server_for_id($opts{id}, $server);
    return $server;
}

# associate a server with an SID.
sub set_server_for_id {
    my ($uic, $id, $server) = @_;
    $uic->{servers}{$id} = $server;
    return $server;
}

# dispose of a server.
sub remove_server {
    my ($uic, $server) = @_;
    delete $uic->{servers}{$server->{sid}};
}

# number of recognized servers.
sub number_of_servers {
    my $uic = shift;
    return scalar keys %{$uic->{servers}};
}

# convenience for UIC clients: returns the only server.
sub main_server {
    my $uic = shift;
    return (values %{$uic->{servers}})[0];
}

# returns a list of recognized servers.
sub servers {
    my $uic = shift;
    return values %{$uic->{servers}};
}

# find a server by its SID.
sub lookup_server_by_id {
    my ($uic, $id) = @_;
    return $uic->{servers}{$id};
}

1
