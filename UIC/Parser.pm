# Copyright (c) 2012, Mitchell Cooper
package UIC::Parser;

use warnings;
use strict;
use utf8;
use feature 'switch';

use Scalar::Util 'looks_like_number';

# %current
#
# (bool)    inside_message:     true if we are in a message (within the brackets)
# (bool)    message_done:       true if the message has been parsed fully (right bracket parsed)
# (number)  message_id:         the numerical message identifier
# (bool)    message_id_done:    true if the message ID is done (left bracket parsed)
#
# (string)  command_name:       the name of the message command
# (bool)    command_done:       true if the command has been parsed fully (colon parsed)
#
# (bool)    inside_parameter:   true if we are in a parameter value (within the parentheses)
# (string)  parameter_name:     the name of the parameter being parsed
# (string)  parameter_value:    the value of the parameter being parsed (inside parentheses)
# (bool)    parameter_escape:   true if the last character was an escape character
# (string)  parameter_type:     the character representing the type of the current parameter


# %final
# (string)  command_name:       the name of the message command
# (hash)    parameters:         hash of name:value parameters
# (number)  message_id:         the message identifier or undef

# Returned parameter types:
#   array                                - UIC::Type::Array
#   object (user, server, channel, etc.) - UIC::Type::Object
#   string                               - UIC::Type::String
#   number                               - UIC::Type::Number
#   boolean                              - UIC::Type::Boolean

sub parse_line {
    my ($line, %current, %final) = shift;
    
    CHAR: foreach my $char (split //, $line) {
    given ($char) {
        
        # space. we handle this here for simplicity, since just about everything trims spaces out.
        when (' ') {
        
            # if we are inside a parameter value, the space is accounted for.
            if ($current{inside_parameter}) {

                # if there is no value, set it to an empty string.
                $current{parameter_value} = q()
                if !defined $current{parameter_value};
                
                $current{parameter_value} .= $char;
            }
            
            # if we are parsing the command name, ...spaces not allowed XXX
            
            
            # otherwise, we do not care about this space at all.
            
        }
        
        # left bracket - starts a message
        when ('[') {
        
            # we can't start a message if we've already finished one.
            if ($current{message_done}) {
                $@ = 'attempted to start a second message';
                return;
            }
        
            $current{inside_message}  = 1;
            $current{message_id_done} = 1;
            $final{message_id} = $current{message_id} if defined $current{message_id};
        }
        
        # right bracket - ends a message
        when (']') {
        
            # if there is no command, something surely has gone wrong. ex: [] or [:]
            if (!defined $current{command_name}) {
                # illegal error. disconnect.
                $@ = 'message is completely empty';
                return;
            }
            
            $final{command_name} = $current{command_name};
        
            # if there is a parameter name, we have a problem.
            if (defined $current{parameter_name}) {
                # illegal error. disconnect.
                $@ = 'message was terminated inside of parameter name';
                return;
            }
        
            # there might not be any parameters. at this point, the command may be done.
            # no colon is necessary if there are no parameters.
            $current{message_done} = 1;
            
            # we're done with the message.
            delete $current{inside_message};
            
        }
        
        # any other characters
        default {
        
            # we are inside a message
            if ($current{inside_message}) {
            
                # we've received the command. it could be a parameter name, value, or type.
                if ($current{command_done}) {
                
                    # backslash - escape character.
                    if ($char eq '\\' && !$current{parameter_escape} && $current{inside_parameter}) {
                        $current{parameter_escape} = 1;
                        next CHAR;
                    }
                    
                    # if we are not inside of the parameter value and it is one of these symbols,
                    # it could be a type indicator (unless we've received part of parameter name already.)
                    if ($char =~ m/[\#\@\$]/ && !$current{inside_parameter} && !defined $current{parameter_name}) {
                        $current{parameter_type} = $char;
                        next CHAR;
                    }
                    
                    # left parenthesis - starts a parameter's value.
                    if ($char eq '(' && !$current{parameter_escape}) {
                        
                        # if there is no type, set it to '' (string).
                        $current{parameter_type} = '' if !defined $current{parameter_type};
                        
                        # if there is no parameter, something is wrong. ex: [command: (value)]
                        if (!defined $current{parameter_name}) {
                        
                            # illegal error. disconnect.
                            $@ = 'a parameter has no name';
                            return;
                            
                        }
                        
                        # start the value.
                        $current{inside_parameter} = 1;
                    }
                
                    # right parenthesis - ends a parameter's value.
                    elsif ($char eq ')' && !$current{parameter_escape}) {
                    
                        # it is legal for a parameter to lack a value or have a value of ""
                        # just saying. no reason to check if parameter_value has a length.
                        
                        $final{parameters} = UIC::ParameterList->new if !$final{parameters};
                        
                        # parse the parameter value.
                        my $result = make_uic_type(
                            $current{parameter_name},
                            $current{parameter_type},
                            $current{parameter_value}
                        );
                        
                        # parameter value parse error.
                        if (!defined $result) {
                            $@ = "unable to parse value of '$current{parameter_name}' parameter: $@";
                            return;
                        }
                        
                        $final{parameters}->add(@$result);
                        
                        delete $current{inside_parameter};
                        delete $current{parameter_name};
                        delete $current{parameter_value};
                        delete $current{parameter_type};
                    }
                    
                    # exclamation mark - indicates a boolean parameter. ex: [someCommand: someParameter(some value) someBool!]
                    elsif ($char eq '!' && !$current{parameter_escape} && !$current{inside_parameter}) {
                        
                        # make sure parameter name is not empty. ex: [command: !]
                        if (!defined $current{parameter_name}) {
                        
                            # illegal error. disconnect.
                            $@ = 'a boolean parameter has no name';
                            return;
                            
                        }
                        
                        # set value to a true value (1).
                        $final{parameters} = UIC::ParameterList->new if !$final{parameters};
                        $final{parameters}->add($current{parameter_name}, 'boolean', 1);
                        
                        delete $current{parameter_name};
                        
                    }
                    
                    
                    # actual characters of the parameter name or value.
                    else {
                    
                        my $key = $current{inside_parameter} ? 'parameter_value' : 'parameter_name';
                        
                        # if this is a parameter name, make sure it is alphanumeric/_.
                        if (!$current{inside_parameter} && $char !~ m/\w/) {
                            $@ = "character '$char' is illegal in parameter name";
                            return;
                        }
                        
                        # if the parameter name or value doesn't exist, create empty string.
                        $current{$key} = q()
                        if !defined $current{$key};
                        
                        # append the character to the parameter name or value.
                        $current{$key} .= $char;
                        
                    }
                    
                    # reset any possible escapes.
                    delete $current{parameter_escape};
                    
                }
                
                # command not yet received. it must be the command name.
                else {
                
                    # if it's a colon, we're done with the command name.
                    if ($char eq ':') {
                    
                        # if there is no command at all, something is wrong.
                        if (!defined $current{command_name}) {
                            # illegal error. disconnect. ex: [:] or [:someParameter(etc)]
                            $@ = 'message has no command name';
                            return;
                        }
                    
                        # colon received - done with command name.
                        $current{command_done} = 1;
                        $final{command_name}   = $current{command_name};
                        next CHAR;
                        
                    }
                    
                    # command names must be alphanumeric/_.
                    if ($char !~ m/\w/) {
                        # illegal error. disconnect. could also be JSON.
                        $@ = "character '$char' is illegal in command name";
                        return;
                    }
                    
                    # if the command name doesn't exist, create empty string.
                    $current{command_name} = q()
                    if !defined $current{command_name};
                    
                    # append the character to the command name.
                    $current{command_name} .= $char;
                    
                }
            }
            
            # outside of message.
            else {
            
                # if it's numerical, it must be a message identifier.
                if ($char =~ m/\d/ && !$current{message_id_done}) {
                    $current{message_id} ||= ''; # this will interpret 1 and 01 as the same.
                    $current{message_id} .= $char;
                    next CHAR;
                }
                
                # other character not inside of a message; illegal!
                $@ = "character '$char' is outside of message bounds";
                return;
                
            }
                
            
        }
    } 
    }
    
    # if a return command has a message identifier, it becomes the messageID parameter.
    if ($final{command_name} eq 'return' && defined $final{message_id}) {
        
        # however, it only makes sense if a messageID parameter is equal.
        if (defined $final{parameters}{messageID} && $final{parameters}{messageID} ne $final{message_id}) {
            $@ = 'in return, message identifier and messageID parameter do not match';
            return;
        }
    
        $final{parameters}{messageID} = $final{message_id};

    }
    
    # we're inside a message? that's not at all valid.
    if ($current{inside_message}) {
        $@ = 'data terminated before end of message';
        return;
    }
    
    return \%final;
}

# make an array for the type indicator and parameter value specified used in ParameterList.
# obviously, boolean types are the single exception.
# sets $@ and returns undef if a parse error occurs.
sub make_uic_type {
    my ($name, $type, $value) = @_;
    given ($type) {
    
    # string
    when ('') { return [$name, 'string', $value] }
    
    # number
    when ('#') {
        if (!looks_like_number($value)) {
            $@ = "'$value' is not numerical";
            return;
        }
        return [$name, 'number', $value];
    }
    
    # array
    when ('@') {
    
        # parse element separation.
        my (%current, @final);
        foreach my $char (split //, $value) { given ($char) {
                    
            # comma separator.
            when (',') {
                next if $current{escape};
                push @final, $current{value} if defined $current{value};
                delete $current{value};
            }
            
            # other character.
            default {
            
                # character escape.
                if ($char eq '\\' && !$current{escape}) {
                    $current{escape} = 1;
                }
            
                # part of value.
                else {
                    $current{value}  = '' unless defined $current{value};
                    $current{value} .= $char;
                    
                    delete $current{escape};
                }

            }
        }}
        
        # final value.
        push @final, delete $current{value} if defined $current{value};

        return [$name, 'array', \@final];
    }
    
    # object
    when ('$') {
        
        # parse type and identifier.
        my ($type, $identifier, %current) = ('', '');
        foreach my $char (split //, $value) { given ($char) {
        
            if ($char eq '.') {
            
                # we've already processed a separator.
                if ($current{got_separator}) {
                    $@ = 'object type has multiple separators';
                    return;
                }
                
                # type is empty.
                if ($type eq '') {
                    $@ = 'object has no type';
                    return;
                }
                
                $current{got_separator} = 1;
            
            }
            
            # other character.
            else {
            
                # part of the identifier.
                if ($current{got_separator}) {
                
                    ## identifiers must be numeric. X_XX: what about scientific notation?
                    # revision: we now use decimal identifiers for users.
                    #if ($char !~ m/\d/) {
                    #    $@ = "character '$char' in object identifier is not numeric";
                    #    return;
                    #}
                
                    $identifier .= $char;
                }
                
                # part of the type.
                else {
                
                    # types must be alphanumeric/_.
                    if ($char !~ m/\w/) {
                        $@ = "character '$char' in object type is not alphanumeric";
                        return;
                    }
                    
                    $type .= $char;
                }
                
            }
        
        }}
        
        return [$name, 'object', [$type, $identifier]];
        
    }
        
    }
    
    $@ = "unknown type";
    return;
}

# encode Perl data into a UIC message.
#
# not intended to convert IDs to objects, numbers to bools, etc.
# simply takes parameters and magically turns them into a UIC message.
#
# UIC::Parser::encode(
#     command_name => 'hello',
#     parameters   => {
#         someParameter => []
#     }
# );
#
# this is not intended to be used directly
# other than in UIC and UICd APIs.
#
# in libuic, be sure to $uic->prepare_parameters_for_sending().
sub encode {
    my $data = {@_};
    my $uic = q();
    
    # message identifier.
    if (defined $data->{message_id}) {
        $uic .= $data->{message_id}.q( );
    }
    
    $uic .= "[ $$data{command_name}";

    # if there are no parameters, we're pretty much done.
    if (!$data->{parameters} || !scalar keys %{$data->{parameters}}){
        $uic .= ' ]';
        return $uic;
    }
    
    # otherwise, start the parameter list.
    $uic .= q(: );
    
    # iterate through each parameter. [name, type, value]
    foreach my $parameter (sort keys %{$data->{parameters}}) {
        my $a =  $data->{parameters}{$parameter};
        return if !ref $a || ref $a ne 'ARRAY';
        my ($type, $value) = @$a;
        
        # boolean.
        if ($type eq 'boolean') {
            $uic .= "$parameter! " if $value;
            next;
        }
        
        my $indicator = '';
        
        # string.
        if ($type eq 'string') {
            # indicator already ''
            # value already set
        }
        
        # number.
        elsif ($type eq 'number') {
            $indicator = '#';
        }
        
        # array.
        elsif ($type eq 'array') {
            $indicator = '@';
            $value     = join ',', map { s/,/\\,/g } @$value;
        }
        
        # object.
        elsif ($type eq 'object') {
            $indicator = '$';
            $value     = $value->[0].q(.).$value->[1];
        }

        $value    =~ s/\(/\\\(/g;
        $value    =~ s/\)/\\\)/g;
        $uic     .=  "$indicator$parameter($value) ";
    }
    
    # close the message. we are done.
    $uic .= ']';
    return $uic;
}

##################
### UJC / JSON ###
##################

# converts a JSON-parsed data object to an output similar to encode().
# [ command, parameters, identifier ]
sub decode_json {
    my $json_data = shift;

    # ensure that the types are valid.
    unless (ref $json_data eq 'ARRAY') {
        $@ = "JSON object is not an array reference";
        return;
    }
    if (ref $json_data->[1] ne 'HASH') {
        $@ = "parameter object is not a HASH reference";
        return;
    }
    if (defined $json_data->[2] && $json_data->[2] !~ m/^(\d*)$/) {
        $@ = "message identifier is not numerical";
        return;
    }
    
    # XXX: does not care about strict types. does not convert to UIC::Types.
    
    # create the hashref.
    return {
        command_name => $json_data->[0],
        parameters   => $json_data->[1],
        message_id   => defined $json_data->[2] ? $json_data->[2] : undef
    }
    
}

1
