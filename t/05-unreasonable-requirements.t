#!/usr/bin/env perl6
use Test;
use JSON::Fast;

plan 3;

is to-json(Inf), "null", "json standard dictates Inf turns into null";
is to-json(-Inf), "null", "json standard dictates -Inf turns into null";
is to-json(NaN), "null", "json standard dictates NaN turns into null";
