#!/bin/bash
set -x 
perl -E '$ha=[{name=>"02"},{name=>1}, {name=>3}]; say "$_->{name}" for sort {$a->{name} <=> $b->{name}} @$ha'
#1
#02
#3
