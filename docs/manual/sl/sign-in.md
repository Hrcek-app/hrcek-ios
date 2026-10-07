# Prijava

[English](../en/sign-in.md) · [Vsebina](index.md)

Hrček za iOS shranjuje strani v vaš Hrček, zato mora najprej vedeti,
kje je in kdo ste. Prijavite se enkrat; aplikacija in meni Deli si
vas nato zapomnita.

## Izpolnjevanje obrazca

**Naslov strežnika** — naslov, na katerem Hrček odprete v brskalniku,
na primer `hrcek.example.com`. Predpono `https://` lahko izpustite;
aplikacija jo doda sama.

**E-pošta** in **Geslo** — enaka kot na spletni strani.

Tapnite **Prijava**. Ko uspe, aplikacija pokaže, kot kdo in na katerem
strežniku ste prijavljeni.

Vaše geslo se v telefonu ne shrani. Aplikacija ga zamenja za žeton za
dostop, ki ga obdrži namesto gesla. Na spletni strani je žeton na
strani odjemalcev viden kot »Hrček za iOS (iPhone)«. iOS aplikacijam
ne pove imena, ki ste ga dali telefonu, zato žetona dveh telefonov
ločite po času, ko sta bila ustvarjena.

## Ko prijava ne uspe

| Aplikacija pravi | Kaj storiti |
|---|---|
| E-poštni naslov ali geslo ni pravilno. | Preverite oboje, enako kot na spletni strani. |
| Pred prijavo potrdite svoj e-poštni naslov. | Odprite potrditveno sporočilo, ki vam ga je poslal Hrček, sledite povezavi in poskusite znova. |
| Naslov se mora začeti s https://. | Aplikacija gesla ne pošlje po nešifrirani povezavi. Uporabite naslov `https://` svojega Hrčka. |
| To ni videti kot spletni naslov. | Preverite, ali je v naslovu strežnika tipkarska napaka. |
| Strežnika ni mogoče doseči. Preverite naslov. | Naslov je morda napačen ali pa strežnik ne deluje. Poskusite ga odpreti v brskalniku. |
| Niste povezani z internetom. | Povežite se z internetom in poskusite znova. |

## Odjava

Tapnite **Odjava** in potrdite. Telefon pozabi vašo prijavo.

**Žeton za dostop deluje, dokler ga ne odstranite.** Če želite biti
prepričani, da ga nihče ne more uporabiti — na primer, ko telefon
podarite — na spletni strani odprite stran odjemalcev
(`/accounts/me/clients/` na vašem strežniku; aplikacija ima povezavo
nanjo) in odstranite »Hrček za iOS« za ta telefon.

Če žeton najprej odstranite na spletni strani, aplikacija to opazi, ko
jo naslednjič odprete ali se vrnete vanjo, in vas prosi, da se znova
prijavite.
