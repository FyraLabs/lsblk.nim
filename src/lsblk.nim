import results
export results
import lsblk/[blockdev, mount]
export blockdev, mount

when not defined(linux):
  {.warn: "The `lsblk` nimble package does not support operating systems other than linux.".}
