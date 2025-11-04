#!/usr/bin/env perl6
use v6;
use JSON::Fast;
use Test;

plan 1;

use MONKEY-TYPING;
augment class DateTime { multi method new(Any:U){ $?CLASS } }
augment class Date { multi method new(Any:U){ $?CLASS } }

multi sub infix:<=~=>(DateTime:D \l, DateTime:D \r){ l.posix == r.posix }
multi sub infix:<=~=>(DateTime:U \l, DateTime:U \r){ True }
multi sub infix:<=~=>(Date:D \l, Date:D \r){ l.day == r.day && l.month == r.month && l.year == r.year }
multi sub infix:<=~=>(Date:U \l, Date:U \r){ True }
multi sub infix:<=~=>(Date:D \l, DateTime:D \r){ l.day == r.day && l.month == r.month && l.year == r.year }
multi sub infix:<=~=>(Instant:D\l, Instant:D\r){ l.to-posix == r.to-posix }
multi sub infix:<=~=>(Instant:U\l, Instant:U\r){ True }


my @data = now.DateTime, DateTime, now, Date.today;
my $json = to-json @data;

my @data-round-trip := from-json $json;

my @tripped;
with @data-round-trip {
    @tripped.push: DateTime.new(.[0]);
    @tripped.push: DateTime.new(.[1]);
    @tripped.push: DateTime.new(.[2]).Instant;
    @tripped.push: Date.new(.[3]);
}

ok all(@tripped »=~=« @data), ‚Roundtrip for DateTime instant, DateTime, Date and Instant instant works‘;

