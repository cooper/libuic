# Copyright (c) 2012, Mitchell Cooper
package UIC::Parser;

use warnings;
use strict;
use utf8;
use feature 'switch';


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


# %final
# (string)  command_name:       the name of the message command
# (hash)    parameters:         hash of name:value parameters

sub parse_line {
    my ($line, %current, %final) = shift;
    
    CHAR: foreach my $char (split //, $line) {
    given ($char) {
        
        # space. we handle this here for simplicity, since just about everything trims spaces out.
        when (' ') {
        
            # if we are inside a parameter value, the space is accounted for.
            if ($current{inside_parameter}) {
            
                # parameter names must be alphanumeric/_.
                if ($char !~ m/\w/) {
                    # illegal error. disconnect. could also be JSON.
                    $@ = "character '$char' is illegal in parameter name";
                    return;
                }
            
                # if there is no value, set it to an empty string.
                $current{parameter_value} = q()
                if !defined $current{parameter_value};
                
                $current{parameter_value} .= $char;
            }
            
            # otherwise, we do not care about this space at all.
            
        }
        
        # left bracket - starts a message
        when ('[') {
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
            
                # we've received the command. it could be a parameter name.
                if ($current{command_done}) {
                
                    # backslash - escape character.
                    if ($char eq '\\' && !$current{parameter_escape}) {
                        $current{parameter_escape} = 1;
                        next CHAR;
                    }
                    
                    # left parenthesis - starts a parameter's value.
                    if ($char eq '(' && !$current{parameter_escape}) {
                        
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
                        
                        # end the value.
                        $final{parameters}{$current{parameter_name}} = $current{parameter_value}; 
                        delete $current{inside_parameter};
                        delete $current{parameter_name};
                        delete $current{parameter_value};
                        
                    }
                    
                    # exclamation mark - indicates a boolean parameter. ex: [someCommand: someParameter(some value) someBool!]
                    elsif ($char eq '!' && !$current{parameter_escape} && !$current{inside_parameter}) {
                        
                        # set value to a true value (1).
                        $final{parameters}{$current{parameter_name}} = 1;
                        delete $current{parameter_name};
                        
                    }
                    
                    
                    # actual characters of the parameter name or value.
                    else {
                    
                        my $key = $current{inside_parameter} ? 'parameter_value' : 'parameter_name';
                        
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
            $@ = "in return, message identifier and messageID parameter do not match";
            return;
        }
    
        $final{parameters}{messageID} = $final{message_id};
        return;
    }
    
    return \%final;
}

# encode Perl data into a UIC message.
#
# not intended to convert IDs to objects, numbers to bools, etc.
# simply takes a string and magically turns it into something it
# already is. no conversion is done at all. this encodes Perl
# data, and does absolutely nothing else.
#
# UIC::Parser::encode(
#     command_name => 'hello',
#     parameters   => {
#         someParameter => 'someValue'
#     }
# );
#
# this is not intended to be used directly
# other than in UIC and UICd APIs.
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
    
    # iterate through each parameter.
    foreach my $parameter (sort keys %{$data->{parameters}}) {
        my $value =  $data->{parameters}{$parameter};
        $value    =~ s/\(/\\\(/g;
        $value    =~ s/\)/\\\)/g;
        $uic     .=  "$parameter($value) ";
    }
    
    # close the message. we are done.
    $uic .= ']';
    return $uic;
}

##################
### UJC / JSON ###
##################

# converts a JSON-parsed data object to an output similar to encode().
# [command, parameters, identifier ]
sub decode_json {
    my $json_data = shift;

    # ensure that the types are valid.
    $@ = "JSON object is not an array reference"
    and return unless ref $json_data eq 'ARRAY';
    $@ = "parameter object is not a HASH reference"
    and return if ref $json_data->[1] ne 'HASH';
    $@ = "message identifier is not numerical"
    and return if defined $json_data->[2] && $json_data->[2] !~ m/^(\d*)$/;
    
    # create the hashref.
    return {
        command_name => $json_data->[0],
        parameters   => $json_data->[1],
        message_id   => defined $json_data->[2] ? $json_data->[2] : undef
    }
    
}

1
