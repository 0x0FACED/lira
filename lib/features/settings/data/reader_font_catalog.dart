class BundledReaderFont {
  final String family;
  final String licenseAsset;

  const BundledReaderFont(this.family, this.licenseAsset);
}

const bundledReaderFonts = [
  BundledReaderFont('Inter', 'assets/fonts/Inter-OFL.txt'),
  BundledReaderFont('Lora', 'assets/fonts/Lora-OFL.txt'),
  BundledReaderFont('Literata', 'assets/fonts/Literata-OFL.txt'),
  BundledReaderFont('Source Serif 4', 'assets/fonts/SourceSerif4-OFL.txt'),
  BundledReaderFont('PT Serif', 'assets/fonts/PTSerif-OFL.txt'),
  BundledReaderFont('Noto Serif', 'assets/fonts/NotoSerif-OFL.txt'),
  BundledReaderFont('Merriweather', 'assets/fonts/Merriweather-OFL.txt'),
  BundledReaderFont('Roboto Slab', 'assets/fonts/RobotoSlab-LICENSE.txt'),
  BundledReaderFont('PT Sans', 'assets/fonts/PTSans-OFL.txt'),
  BundledReaderFont('Noto Sans', 'assets/fonts/NotoSans-OFL.txt'),
  BundledReaderFont('Roboto', 'assets/fonts/Roboto-OFL.txt'),
];
