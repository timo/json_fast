#!/usr/bin/env perl6
use v6;
use JSON::Fast;
use Test;

plan 1;

my @out = ( '{ "a" : "1" }' xx 10_000 )
    .race(:degree(8),:batch(100))
    .map: { to-json( from-json($_) ) };

is @out.elems, 10_000, 'right number of items';

# vim: ft=perl6
