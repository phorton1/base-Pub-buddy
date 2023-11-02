# Buddy Windows Installer Releases

This directory contains the **Windows Installer** to install **Buddy**
and the [**fileClient**](https://github.com/phorton1/base-apps-fileClient)
to any Microsoft Windows machine.

Buddy itself is *Pure Perl*. The executable (EXE) files installed by this
program use the ancient **Cava Packager v2.0.80.263** to *package* the Perl
for Buddy with a similarly ancient version of **ActivePerl v5.12**.

Unfortunately, because of the unavailability of a more current version of the
*Cava Packager* that works with more modern versions of Perl, along with the
fact that are *no good alternatives* to it for packaging and releasing Perl
programs as Windows executables, I am effectively **unable** to publish the
complete method by which I build and release Buddy (and the fileClient)
as EXE files.

Let's just say it's really **arcane** and I doubt anyone but me would ever
try to build Buddy and/or the fileClient that way.

Nonetheless, I have taken the effort to create the Windows Installer so that
you don't have to install the various pieces of Perl and/or have a Perl interpreter
on your machine in order to run Buddy and the fileClient because I think
Buddy itself is a **very useful program** and a good alternative to
[Putty](https://www.putty.org/) or the **Arduino IDE Serial Monitor**
for many purposes.

Having said that, please feel free to run the **Windows Installer
Executable** with confidence.  All of the **source** code for Buddy,
the fileClient, and all my other programs can be found here on GitHub,
and I guarantee that they are **free of any malware or adware**.

### Version History

| date 			| version 		| notes	                                    |
| ------------- | ------------- | ----------------------------------------- |
| 2023-10-10    | 1.0.2			| moved from Pub:: to apps::				|
| 2023-10-09    | 1.0.1			| moved Pub::FC to Pub::fileClient			|
| 2023-10-08    | 1.0.0			| initial release							|
