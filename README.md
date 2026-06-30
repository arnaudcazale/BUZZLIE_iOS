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

## Architecture (`BuzzlieTest/`)

Portage **au pixel & UX près** de l'app Android (`../Android`), même style Apple/iOS médical,
français, accent teal. Découpage miroir :

- **`BLE/`** : `BuzzlieGatt` (UUIDs/opcodes/limites), `ConfigCodec` (encode/décode little-endian,
  **bit-à-bit identique au firmware**, couvert par tests), `BleModels`, `BuzzlieBleManager`
  (CoreBluetooth : scan, auto-connect, MTU auto, ops `async` syncTime/writeConfig/readSchedule/
  sendControl en `.withResponse`, publishers `status`/`battery`/`schedule`/`events`).
- **`Data/`** : `ReminderUi` (RELATIVE|ABSOLUTE + day_mask + ancre), `VibrationPreset`, `AppSettings`
  (Codable), `Time` (`weekdayMon0 = ((epoch/86400)+3)%7` UTC, comme le firmware), `ReminderStore`
  (JSON dans Application Support), `ConfigMapper` (toConfigDraft + merge schedule).
- **`ViewModel/BuzzlieViewModel`** : `@MainActor ObservableObject`, push débouncé 500 ms,
  `onConnected` = readSchedule → merge → **sync heure puis config**, purge des one-shots expirés.
- **`UI/`** : `Theme/` (couleurs/typo/metrics exacts), `Components/` (SegmentedControl à pastille
  ressort critique-amorti, WheelPicker iOS natif, BatteryRing trim -90°, InsetGroup, bannières,
  ConnectSheet, …), `Screens/` (TabView Rappels/Bracelet/Debug — Debug masqué hors `#if DEBUG` —
  + sheets connexion/éditeur).

## Build

Projet généré par **XcodeGen** (`brew install xcodegen` puis `xcodegen generate`) depuis
`project.yml` — le `.xcodeproj` n'est pas versionné (régénérable). Cible **iOS 17**, Xcode 16,
mode langage Swift 5. Le BLE (CoreBluetooth) ne tourne **pas** sur simulateur → tester sur iPhone
physique. Tests codec : `xcodebuild -scheme BuzzlieTest test` (vérifie l'octet exact du blob).

## État

POC porté depuis Android : UI complète (3 onglets, éditeur relatif/absolu, presets vibration,
persistance), couche BLE CoreBluetooth, codec vérifié par tests. **À faire** : test BLE bout-en-bout
sur iPhone physique + bracelet (build OPEN_GATT), icône d'app, dark theme affiné.
