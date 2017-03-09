#!/usr/bin/env perl6
use v6;
use lib 'lib';
use JSON::Fast;
use Test;


my @t =
    '{ "a" : "b\u00E5" }' => { 'a' => 'bå' },
    '[ "\u2685" ]' => [ '⚅' ],
    '[ "̅hello" ]' => [ "\x[305]hello" ],
    '{ "̅hello": "goodbye" }' => { "\x[305]hello" => "goodbye" };

my @out =
    "\{\"a\": \"bå\"}",
    '["⚅"]',
    '["̅hello"]',
    '{"̅hello": "goodbye"}';

plan (+@t * 2);
my $i = 0;
for @t -> $p {
    my $json = from-json($p.key);
    is-deeply $json, $p.value, "Correct data structure for «{$p.key}»";
    is to-json($json, :pretty(False)), @out[$i++], 'to-json test';
}
