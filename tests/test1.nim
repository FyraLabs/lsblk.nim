# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import unittest

import lsblk

test "listBlockDevices":
  for bd in listBlockDevices():
    echo $bd

test "disk_name and size":
  for bd in listBlockDevices():
    echo bd.disk_name
    echo bd.size

test "maj:min":
  for bd in listBlockDevices():
    if bd.is_part:
      echo bd.maj_min

test "listMounts":
  for mnt in getMounts().get:
    echo mnt
