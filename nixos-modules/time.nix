{ ... }:

{
  # Windows wants hardware clock in local time instead of UTC
  # This is required for compatibility with windows
  time.hardwareClockInLocalTime = true;
  # Set your time zone.
  time.timeZone = "America/Denver";
}
