#!/usr/bin/env perl6
use Test;
use JSON::Fast;

plan 6;

is to-json(Inf), "null", "json standard dictates Inf turns into null";
is to-json(-Inf), "null", "json standard dictates -Inf turns into null";
is to-json(NaN), "null", "json standard dictates NaN turns into null";

{
    my $*JSON_NAN_INF_SUPPORT = 1;

    is to-json(Inf), "Inf", '$*JSON_NAN_INF_SUPPORT allows for Inf';
    is to-json(-Inf), "-Inf", '$*JSON_NAN_INF_SUPPORT allows for -Inf';
    is to-json(NaN), "NaN", '$*JSON_NAN_INF_SUPPORT allows for NaN';
}
