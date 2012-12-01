# Copyright (c) 2012, Mitchell Cooper
# UIC: manages servers, users, and channels on a UIC network or server.
# performs tasks that do not fall under the subcategories of server, user, connection, or channel.
package UIC 1.0;

use warnings;
use strict;
use utf8;
use feature qw(switch);
use parent 'EventedObject';

use EventedObject;

use UIC::Server;
use UIC::User;
use UIC::Channel;
use UIC::Parser;
use UIC::ParameterList;

use Scalar::Util qw(looks_like_number blessed);

# main UIC object is used especially in UICd, which only has a single UIC object.
# however, software can have multiple UIC objects by supplying a 'uic' option to the
# constructors of UIC::Server, UIC::Channel, and UIC::User.
our $main_uic;

sub new {
    my $uic = shift->SUPER::new(@_);
    $main_uic = $uic unless $main_uic;
    
    # register the object fetchers.
    $uic->register_object_type_handler('usr', \&get_user);
    $uic->register_object_type_handler('srv', \&get_server);
    $uic->register_object_type_handler('chn', \&get_channel);
    
    return $uic;
}

###############
### LOGGING ###
###############

sub log {
}

####################################
### HANDLING AND PREPARING DATA ####
####################################

sub parse_data {
    my ($uic, $data) = @_;
    # blah blah, call handlers.
}

# registers a data parsing handler.
sub register_parse_handler {
}

# converts any instances of UIC::Object to actual objects if possible.
sub process_parameters {
    my ($uic, $parameters) = @_;
    return unless $parameters;
    foreach my $param ($parameters->keys) {
        my $val = $parameters->{$param};
        next if !ref $val || ref $val ne 'ARRAY';
        next unless $parameters->type_of($param) eq 'object';
        $parameters->{$param} = $uic->fetch_object($parameters->{$param}[0], $parameters->{$param}[1]);
    }
    return $parameters;
}

# converts objects, arrays, etc. to [type, value] arrays values for sending.
sub prepare_parameters_for_sending {
    my ($uic, $parameters) = @_;

    foreach my $param (keys %$parameters) {
        my $val = $parameters->{$param};
        
        
        # if it's blessed and has methods 'uic_id' and 'uic_type', it's an object.
        if (blessed $val && $val->can('uic_id') && $val->can('uic_type')) {
            $parameters->{$param} = ['object', [$val->uic_type, $val->uic_id]];
            next;
        }
        
        # if it's not a reference, just assume it is a string (even if it's not a string)
        if (!ref $val) {
        
            # unless it is equal to TRUE or FALSE because then it must be boolean.
            if ($val eq  UIC::TRUE()) { $parameters->{$param} = ['boolean', 1    ] and next }
            if ($val eq UIC::FALSE()) { $parameters->{$param} = ['boolean', undef] and next }
        
            $parameters->{$param} = ['string', $val];
            next;
        }
        
        # if it's an array reference, it's obviously an array.
        if (ref $val eq 'ARRAY') {
            $parameters->{$param} = ['array', $val];
            next;
        }
        
        # if it's a scalar reference, we will guess it's a number.
        if (ref $val eq 'SCALAR' && looks_like_number($$val)) {
            $parameters->{$param} = ['number', $$val];
            next;
        }
        
    }
    return $parameters;
}

####################
### OBJECT TYPES ###
####################

# register an object type handler.
# object type handlers convert UIC object types into a real Perl object.
#
# returns the type handler name.
#
# by the way, the last-called handler is always used
# (which would be the one with the LOWEST priority)
# but honestly, you should only have one handler per type.
# there's just no rule that says so.
#
sub register_object_type_handler {
    my ($uic, $type, $callback) = @_;
    return if !ref $callback || ref $callback ne 'CODE';
    $uic->{type_callback}{$type} = $callback;
    my $name = "uic.objectTypeHandler.$type";
    
    $uic->register_event(
        $name => $callback,
        name  => $name
    ) or return;
    
    $uic->log("registered object type '$type'");
    return $name;
}

# returns an object of $type with ID $id.
sub fetch_object {
    my ($uic, $type, $id) = @_;
    $uic->fire_event("uic.objectTypeHandler.$type");
    return unless $uic->{event_return};
    return $uic->{event_return};
}

#######################
### MESSAGE RETURNS ###
#######################


# note: return callbacks are deleted automatically after being fired.


# store a callback for when return is received.
# returns the callback identifier.
sub register_return_handler {
    my ($uic, $id, $callback, $parameters) = @_;
    my $name = "uic.returnHandler.$id";
    
    # callback must be code reference and parameters must be hash reference.
    return unless ref $callback eq 'CODE';
    return if defined $parameters && ref $parameters ne 'HASH'; 

    $uic->register_event(
       $name => sub {
            my $info = shift;
            
            # TODO: check types.
            # parameter types are stored in $uic->{event_data}{parameters}
            
            $callback->($parameters, $info);
        },
        name => $name,
        data => $parameters
    ) or return;
    
    return $name;
}

# fire a return callback.
sub fire_return {
    my ($uic, $id, $parameters, $info) = @_;
    my $name = "uic.returnHandler.$id";
    $uic->fire_event($name, $info);
    $uic->delete_event($name);
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
    $priority   = defined $priority ? $priority : -100;
    $package  ||= (caller)[0];
    
    # make sure callback is CODE and parameters is HASH.
    $uic->log('callback is not a CODE reference.')
    and return if !ref $callback || ref $callback ne 'CODE';
    
    # parameters must be hash reference.
    $uic->log('parameters is not a HASH reference.')
    and return if !ref $parameters || ref $parameters ne 'HASH';
    
    # make sure the types are valid.
    my @valid = qw(number boolean string user server channel);
    foreach my $parameter (keys %$parameters) {
       $uic->log("invalid type '$$parameters{$parameter}'")
       and return unless scalar grep { $_ eq $parameters->{$parameter} } @valid;
    }
    
    # generate an identifier.
    my $id   = defined $uic->{handlerID} ? ++$uic->{handlerID} : ($uic->{handlerID} = 0);
    my $name = "uic.commandHandler.$command.$id";
    
    # create event_data.
    my %data = (
        command    => $command,
        callback   => $callback,
        parameters => $parameters, # parameter types.
        priority   => $priority,
        package    => $package,
        id         => $id,
        actualID   => $name
    );
    
    # register the event.
    $uic->register_event(
        "uic.commandHandler.$command" => \&_handler_callback,
        name     => $name,
        data     => \%data,
        with_obj => 1
    ) or return;
    
    $uic->log("registered handler $id of priority $priority for '$command' command to package $package");

    return $name;
}

# not to be used directly.
sub _handler_callback {  # actual parameter values.
    my ($uic, $info_sub, $parameters, $return) = @_;
    my $h = $uic->{event_data};
    
    # handle parameters.
    my $final_params = UIC::ParameterList->new;
    
    # create parameters list, filtering incorrect types.
    if ($parameters) {
        PARAMETER: foreach my $parameter ($parameters->keys) {
            
            # types do not match.
            next PARAMETER
             if $h->{parameters}{$parameter} &&
             $h->{parameters}{$parameter} ne $parameters->type_of($parameter));
            
            # okay, let's add the parameter.
            $final_params->add($parameter, $parameters->type_of($parameter), $parameters->{$parameter})
            if exists $parameters->{$parameter};

        }
    }
    
    # create information object.
    my %info = (
        caller   => [caller 1],
        command  => $h->{command},
        priority => $uic->{event_info}{priority}
    );
    
    # call info sub.
    $info_sub->(\%info);
    
    # call it. don't continue if it returns a false value.
    $uic->{event_data}{callback}($final_params, $return, \%info) or $uic->{event_stop} = 1;
    
    # return 1 if wants_return.
    return 1 if $info{wants_return};
    return;
    
}

# fire a command's handlers.
# $uic->fire_handler('someCommand', {
#     someParameter => '0',
#     someOther     => 'hello!'
# });
# returns a hash reference of return parameters if a message ID is specified.
# the caller which handles the data is then responsible for sending a return command.
# otherwise, fire_handler() returns undef.
sub fire_handler {
    my ($uic, $command, $parameters, $info_sub) = @_;
    my $return = {};
   
    # fire the event.
    $uic->fire_event("uic.commandHandler.$command" => $info_sub, $parameters, $return);

    # return $return if the last callback returned one.
    return $return if $uic->{event_return};
    return;
    
}

# delete a command handler.
sub delete_handler {
    my ($uic, $command, $id) = @_;
    $uic->delete_event($command => $id);
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
    delete $uic->{servers}{$server->{id}};
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

######################
### MANAGING USERS ###
######################

# create a user and associate it with this UIC object.
sub new_user {
    my ($uic, %opts) = @_;
    my $user = $uic->subclass('User')->new(%opts);
    $uic->set_user_for_id($opts{id}, $user);
    return $user;
}

# associate a user with a UID.
sub set_user_for_id {
    my ($uic, $id, $user) = @_;
    $uic->{users}{$id} = $user;
    return $user;
}

# dispose of a user.
sub remove_user {
    my ($uic, $user) = @_;
    delete $uic->{users}{$user->{id}};
}

# number of recognized users.
sub number_of_users {
    my $uic = shift;
    return scalar keys %{$uic->{users}};
}

# returns a list of recognized users.
sub users {
    my $uic = shift;
    return values %{$uic->{users}};
}

# find a user by his UID.
sub lookup_user_by_id {
    my ($uic, $id) = @_;
    return $uic->{users}{$id};
}

###########################
### UIC OBJECT FETCHING ###
###########################

sub get_user {

}

sub get_server {
    shift->lookup_server_by_id(shift);
}

sub get_channel {

}

#####################
### MISCELLANEOUS ###
#####################

sub TRUE  () { '$_UIC_TRUE_$'  }
sub FALSE () { '$_UIC_FALSE_$' }

1
