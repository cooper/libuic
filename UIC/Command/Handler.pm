# Copyright (c) 2012, Mitchell Cooper
# UIC::Command::Handler: represents a single handler of a UIC command.
package UIC::Command::Handler;

# create a new command handler object.
# UIC::Command::Handler->new('someCommand', {
#     someParameter => 'string',
#     someOther     => 'number'
# });
sub new {
    my ($class, $command, $parameters) = @_;
    return bless {
        command    => $command,
        parameters => $parameters
    }, $class;
}

# returns a true value if the handler accepts a certain parameter.
sub has_parameter {
    my ($handler, $parameter) = @_;
    return defined $handler->{parameters}{$parameter};
}

# returns a the type a parameter has.
sub type_of_parameter {
    my ($handler, $parameter) = @_;
    return $handler->{parameters}{$parameter} if $handler->has_parameter($handler);
    return;
}

1
