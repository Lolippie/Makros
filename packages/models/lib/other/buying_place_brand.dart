enum BuyingPlaceBrand {
  // Grande distribution
  lidl(
    name: 'Lidl',
    sirens: ['343262622'],
  ),
  carrefour(
    name: 'Carrefour',
    sirens: ['672050085'],
  ),
  auchan(
    name: 'Auchan',
    sirens: ['481986446', '410409015'],
  ),
  leclerc(
    name: 'E.Leclerc',
    sirens: ['642007991', '882736077', '482070182']
  ),
  intermarche(
    name: 'Intermarché',
    sirens: ['722064102'],
  ),
  systemeU(
    name: 'Magasins U',
    sirens: ['304602956']
  ),
  aldi(
    name: 'Aldi',
    sirens: ['444330641'],
  ),
  netto(
    name: 'Netto',
    sirens: ['722064102'],
  ),

  // Enseignes de proximité
  monoprix(
    name: 'Monoprix',
    sirens: ['552018020'],
  ),
  franprix(
    name: 'Franprix',
  ),
  casino(
    name: 'Casino',
    sirens: ['554501171'],
  ),
  spar(
    name: 'SPAR',
    sirens: ['554501171'],
  ),
  vival(
    name: 'Vival',
    sirens: ['554501171'],
  ),

  // Enseignes spécialisées
  biocoop(
    name: 'Biocoop',
  ),
  picard(
    name: 'Picard',
    sirens: ['784939688'],
  ),
  grandFrais(
    name: 'Grand Frais',
  ),
  naturalia(
    name: 'Naturalia',
  ),
  fresh(
    name: 'Fresh',
  ),

  // Autres enseignes
  colruyt(
    name: 'Colruyt',
    sirens: ['789139789'],
  ),
  supermarcheMatch(
    name: 'Supermarché Match',
    sirens: ['785480351'],
  ),
  bAndM(
    name: 'B&M',
  ),
  costco(
    name: 'Costco',
    sirens: ['513637918'],
  );

  final String name;
  final List<String> sirens;

  const BuyingPlaceBrand({
    required this.name,
    this.sirens = const [],
  });
}