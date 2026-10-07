{ ... }:
{
  # University of Utah's PaperCut Mobility Print queue. Credentials are
  # requested by the print dialog and kept out of the Nix store.
  hardware.printers.ensurePrinters = [
    {
      name = "RedPrintMobilityPrint";
      description = "University of Utah RedPrint";
      location = "University of Utah";
      deviceUri = "ipp://mps-prnt-p1.ad.utah.edu:9163/printers/RedPrintMobilityPrint";
      model = "everywhere";
      ppdOptions."auth-info-required" = "username,password";
    }
  ];

  # Niri already provides both portal backends; route sandboxed print dialogs
  # through GTK without installing or configuring a GNOME desktop.
  xdg.portal.config.niri."org.freedesktop.impl.portal.Print" = "gtk";
}
