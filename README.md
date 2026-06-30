# BUZZLIE — App iOS

App iOS compagnon du bracelet haptique **BUZZLIE** (nRF52832), pendant de l'app Android
(`../Android`). Pilote le bracelet en BLE : programmer des rappels (→ vibration à l'heure
voulue), synchroniser l'heure, lire batterie/status.

> Repo git indépendant. Le projet Android vit dans `../Android`, le firmware dans
> `../../Firmware`, le hardware dans `../../Hardware`.

## Cas d'usage produit

- **Cassie** (enfant) : rappel patch ponctuel « dans +3h30 ».
- **Henri** (senior) : médicaments à heures fixes quotidiennes.

UI cible : style Apple/iOS, médical apaisant, français, accent teal/vert d'eau.

## Contrat BLE (doit matcher le firmware au bit près, little-endian)

- Nom advertising `BUZZLIE-XXXX`. Service `B022B000-5A1E-4D6B-9E2F-C0DEBA77E51E`.
- Chars : Config `B022B001` (WRITE), TimeSync `B022B002` (WRITE u32 epoch),
  Status `B022B003` (READ/NOTIFY 8 o), Control `B022B004` (WRITE opcode). BAS `0x2A19`.

## État

À démarrer.
