# Signing in

[Slovenščina](../sl/sign-in.md) · [Contents](index.md)

Hrček for iOS saves pages to your own Hrček, so it first needs to know
where that is and who you are. You sign in once; the app and the Share
sheet then remember you.

## Filling in the form

**Server address** — the address you open Hrček at in your browser,
for example `hrcek.example.com`. You can leave out `https://`; the app
adds it.

**Email** and **Password** — the same ones you use on the website.

Tap **Sign in**. When it works, the app shows who you are signed in as
and on which server.

Your password is not stored on the phone. The app trades it for an
access token, which is what it keeps. On the website, the token shows
up on your clients page as "Hrček for iOS (iPhone)". iOS does not tell
apps the name you gave your phone, so if you sign in on two phones,
tell them apart by when the token was created.

## When signing in fails

| The app says | What to do |
|---|---|
| The email address or password is not correct. | Check both, the same as on the website. |
| Confirm your email address before signing in. | Open the confirmation email Hrček sent you and follow its link, then try again. |
| The address must start with https://. | The app does not send your password over an unencrypted connection. Use the `https://` address of your Hrček. |
| That doesn't look like a web address. | Check the server address for typing mistakes. |
| Can't reach the server. Check the address. | The address may be wrong, or the server may be down. Try opening it in your browser. |
| You're offline. | Connect to the internet and try again. |

## Signing out

Tap **Sign out** and confirm. The phone forgets your sign-in.

**The access token keeps working until you remove it.** To make sure
nobody can use it — for example when you give the phone away — open
your clients page on the website (`/accounts/me/clients/` on your
server; the app links to it) and remove "Hrček for iOS" for this phone.

If you remove the token on the website first, the app notices the next
time you open it or return to it, and asks you to sign in again.
