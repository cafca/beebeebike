# Datenschutzerklärung

*Stand: 2026-04-23*

## 1. Verantwortlicher

Verantwortlicher im Sinne der DSGVO:

![Verantwortlicher: Name, Anschrift und E-Mail](/legal/provider.png)

## 2. Überblick

beebeebike ist ein fahrradfreundlicher Routenplaner für Berlin. Wir verarbeiten personenbezogene Daten ausschließlich, um den Dienst bereitzustellen. Es findet **kein Verkauf** und **keine Weitergabe zu Werbezwecken** statt.

Karten-Kacheln (MapLibre) und die Routing-Engine (GraphHopper) betreiben wir **selbst** auf einem bei der Hetzner Online GmbH (Gunzenhausen, Deutschland) gemieteten Server. Es findet **keine** Weiterleitung an externe Kartenanbieter (z. B. Google, Mapbox) oder externe Routing-Dienste statt.

## 3. Verarbeitete Daten

| Datenkategorie | Zweck | Rechtsgrundlage | Speicherort |
|---|---|---|---|
| E-Mail-Adresse und Passwort-Hash (Argon2) | Konto-Anmeldung (optional) | Art. 6 Abs. 1 lit. b DSGVO | Hetzner-Server (PostGIS) in Deutschland |
| Bewertungs-Polygone | Personalisiertes Routing | Art. 6 Abs. 1 lit. b / lit. f DSGVO | Hetzner-Server (PostGIS) in Deutschland |
| Gespeicherte Standorte (z. B. Zuhause) | Komfort-Funktion | Art. 6 Abs. 1 lit. b DSGVO | Hetzner-Server (PostGIS) in Deutschland |
| Routenanfragen (Start-/Zielkoordinaten) | Routenberechnung | Art. 6 Abs. 1 lit. b DSGVO | Nur transient im Arbeitsspeicher — keine dauerhafte Speicherung |
| Sitzungs-Cookie (zufällige UUID) | Anmeldung / Gastmodus | Art. 6 Abs. 1 lit. f DSGVO | Hetzner-Server; Ablauf nach 30 Tagen |
| Suchanfragen (Ortssuche) | Geocoding | Art. 6 Abs. 1 lit. b / lit. f DSGVO | Weiterleitung an Auftragsverarbeiter (siehe Abschnitt 5) |
| Aggregierte Seitenaufrufe + Session-Cookie (nur Web-App) | Reichweitenmessung (selbst gehostet, keine Cross-Site-Tracker, keine Wiedererkennung über Sitzungen hinweg) | Art. 6 Abs. 1 lit. f DSGVO | Hetzner-Server in Deutschland — keine Weitergabe an Dritte |

## 4. Gast-Modus

Ohne Konto können Sie beebeebike anonym nutzen. Dabei wird lediglich eine zufällige Sitzungs-ID als Cookie gesetzt. Bewertungen, die Sie als Gast anlegen, werden serverseitig an diese Sitzungs-ID gebunden gespeichert, damit sie bei späteren Besuchen weiterverwendet werden können. Eine Zuordnung zu Ihrer Person findet nicht statt.

## 5. Empfänger / Auftragsverarbeiter

Folgende externe Dienstleister erhalten personenbezogene Daten in unserem Auftrag. Mit allen besteht ein Vertrag zur Auftragsverarbeitung nach Art. 28 DSGVO.

- **Server-Hosting:** Hetzner Online GmbH, Industriestr. 25, 91710 Gunzenhausen, Deutschland. Unsere Datenbank, die Routing-Engine und die Karten-Kacheln laufen auf einem bei Hetzner gemieteten Server in einem deutschen Rechenzentrum.
- **Geocoding (Ortssuche):** Komoot GmbH, Berlin, Deutschland — betreibt den Dienst *Photon* (`photon.komoot.io`). Ihre Sucheingabe wird über unseren Server weitergeleitet; Konto-Daten werden dabei nicht übertragen.

## 6. Speicherdauer

- **Konto-Daten:** bis zur Löschung durch Sie. Ein Konto kann jederzeit in der App unter *Einstellungen → Konto löschen* entfernt werden; dabei werden alle damit verknüpften Bewertungen, Standorte und Sitzungen unwiderruflich gelöscht.
- **Anonyme Sitzungen:** 30 Tage.
- **Routenanfragen:** nicht persistiert.
- **Server-Logfiles:** maximal 14 Tage zu Sicherheits- und Stabilitätszwecken.

## 7. Ihre Rechte

Nach Art. 15–22 DSGVO haben Sie das Recht auf:

- **Auskunft** (Art. 15)
- **Berichtigung** (Art. 16)
- **Löschung / "Recht auf Vergessenwerden"** (Art. 17) — vollständig per App-Funktion oder auf Anfrage
- **Einschränkung der Verarbeitung** (Art. 18)
- **Datenübertragbarkeit** (Art. 20) — auf Anfrage per E-Mail
- **Widerspruch** (Art. 21)

Wenden Sie sich dafür an die im Impressum genannte Kontaktadresse.

## 8. Beschwerderecht

Sie haben das Recht, sich bei einer Datenschutz-Aufsichtsbehörde zu beschweren. Zuständig ist die Behörde am Ort des Verantwortlichen (siehe Abschnitt 1 und Impressum).

## 9. Keine automatisierte Entscheidungsfindung

Es findet keine automatisierte Entscheidungsfindung einschließlich Profiling im Sinne von Art. 22 DSGVO statt.

## 10. Änderungen

Wir passen diese Erklärung an, wenn sich technische Gegebenheiten oder die Rechtslage ändern. Maßgeblich ist die jeweils unter `beebeebike.com/datenschutz` veröffentlichte Fassung.
