#!/usr/bin/env perl6
use v6;
use lib 'lib';
use JSON::Fast;
use Test;


my @t =
    '{ "a" : "b\u00E5" }' => { 'a' => 'bå' },
    '[ "\u2685" ]' => [ '⚅' ],
    '{"b" : "ab\r\nc" }' => { 'b' => "ab\r\nc" };

my @out =
    "\{\"a\": \"bå\"}",
    '["⚅"]',
    '{"b": "ab\r\nc"}';

plan (+@t * 2);
my $i = 0;
for @t -> $p {
    my $json = from-json($p.key);
    is-deeply $json, $p.value, "Correct data structure for «{$p.key}»";
    is to-json($json, :pretty(False)).lc, @out[$i++].lc, 'to-json test';
}
