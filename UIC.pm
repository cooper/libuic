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

use UIC::Type::String;
use UIC::Type::Number;
use UIC::Type::Array;
use UIC::Type::Object;

use Scalar::Util qw(looks_like_number blessed);

# main UIC object is used especially in UICd, which only has a single UIC object.
# however, software can have multiple UIC objects by supplying a 'uic' option to the
# constructors of UIC::Server, UIC::Channel, and UIC::User.
our $main_uic;

sub new {
    my $uic = shift->SUPER::new(@_);
    $main_uic = $uic unless $main_uic;
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

# converts any instances of UIC::Object to actual objects if possible.
sub process_parameters {
    my ($uic, $parameters) = @_;
    foreach my $param (keys %$parameters) {
        my $val = $parameters->{$param};
        next unless ref $val;
        next unless $val->isa('UIC::Type::Object');
        $parameters->{$param} = $uic->fetch_object($val->type, $val->id);
    }
    return $parameters;
}

# converts objects, arrays, etc. to UIC::Type values for sending.
sub prepare_parameters_for_sending {
    my ($uic, $parameters) = @_;
    
    foreach my $param (keys %$parameters) {
        my $val = $parameters->{$param};
        
        # if it's blessed and has methods 'uic_id' and 'uic_type', it's an object.
        if (blessed $val && $val->can('uic_id') && $val->can('uic_type')) {
            $parameters->{$param} = UIC::Object->new($val->uic_type, $val->uic_id);
            next;
        }
        
        # otherwise...
        # if it's blessed, we will assume it's already prepared and an instance of UIC::Type.
        # using UIC::Type in a public send method forces a specific type. in particular,
        # anything that is not a reference (including plain numbers) will be interpreted as
        # strings by this method. numbers must always be UIC::Type::Number in advance.
        next if blessed $val;
        
        # if it's not a reference, just assume it is a string (even if it's not a string)
        if (!ref $val) {
            $parameters->{$param} = UIC::Type::String->new($val);
            next;
        }
        
        # if it's an array reference, it's obviously an array.
        if (ref $val eq 'ARRAY') {
            $parameters->{$param} = UIC::Type::Array->new(@$val);
            next;
        }
        
    }
    return $parameters;
}

####################
### OBJECT TYPES ###
####################

# register an object type handler.
# object type handlers convert instances of UIC::Type::Object into a real Perl object.
sub register_object_type_handler {
    my ($uic, $type, $callback) = @_;
    return if !ref $callback || ref $callback ne 'CODE';
    $uic->{type_callback}{$type} = $callback;
    $uic->log("registered object type '$type'");
}

# returns an object of $type with ID $id.
sub fetch_object {
    my ($uic, $type, $id) = @_;
    return unless $uic->{type_callback}{$type};
    return $uic->{type_callback}{$type}($id);
}

#######################
### MESSAGE RETURNS ###
#######################

# store a callback for when return is received.
sub register_return_handler {
    my ($uic, $id, $callback, $parameters) = @_;
    return unless ref $callback eq 'CODE';
    return if defined $parameters && ref $parameters ne 'HASH';
    $uic->{return_callback}{$id} ||= [];
    push @{$uic->{return_callback}{$id}}, [$callback, $parameters];
}

# fire a return callback.
sub fire_return {
    my ($uic, $id, $parameters, $info) = @_;
    return unless $uic->{return_callback}{$id};
    
    foreach my $r (@{$uic->{return_callback}{$id}}) {
    
        # convert types if necessary.
        if ($r->[1]) {
            foreach my $parameter (keys %{$r->[1]}) {
                $parameters->{$parameter} =
                $uic->interpret_string_as($r->[1]{$parameter}, $parameters->{$parameter})
                if exists $parameters->{$parameter};
            }
        }
   
        # call it.
        $r->[0]->($parameters, $info);
        
    }
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
    and return if !ref $callback || ref $callback ne 'CODE';
    
    if ($parameters ne 'all') {
        $uic->log('parameters is not a HASH reference.')
        and return if !ref $callback || ref $parameters ne 'HASH';
    }
    
    # make sure the types are valid.
    if (ref $parameters) {
        my @valid = qw(number bool string user server channel);
        foreach my $parameter (keys %$parameters) {
           $uic->log("invalid type '$$parameters{$parameter}'")
           and return unless scalar grep { $_ eq $parameters->{$parameter} } @valid;
        }
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
    
        # handle parameters.
        my %final_params;
        if ($parameters) {
        
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

#####################
### MISCELLANEOUS ###
#####################

sub TRUE  () { '$_UIC_TRUE_$'  }
sub FALSE () { '$_UIC_FALSE_$' }

1
