# Lutim

## What Lutim means?
It means Let's Upload That Image.

## What does it do?
It stores images and allows you to see them, download them or share them on social networks. From version 0.5, the gif images can be displayed as animated gifs in Twitter, but you need an HTTPS server (Twitter requires that. Lutim detects if you have a HTTPS server and displays a static image twitter card if you don't);

Images are indefinitely stored unless you request that they will be deleted at first view or after 24 hours / one week / one month / one year.

## License
Lutim is licensed under the terms of the AGPL. See the LICENSE file.

## Official instance
You can see it working at https://lut.im.

## Logo
Lutim's logo is an adaptation of [Lutin](http://commons.wikimedia.org/wiki/File:Lutin_by_godo.jpg) by [Godo](http://godoillustrateur.wordpress.com/), licensed under the terms of the CC-BY-SA 3.0 license.

![Lutim's logo](https://lut.im/img/Lutim_small.png)

## Wiki

The official wiki contains all you need to know about Lutim (installation, API, etc.). Go to <https://framagit.org/luc/lutim/wikis/home> or clone it:

```
git clone https://framagit.org/luc/lutim.wiki.git
```

## Encryption

Lutim does encryption on the server if asked to, but does not store the key.

The encryption is done on the server since Lutim is made to be usable even without javascript. If you want to add client-side encryption for javascript-enabled browsers, patches are welcome.

## Internationalization

Lutim comes with English, French and Spanish languages. It will choose the language to display from the browser's settings.

## Authors

See [AUTHORS.md](AUTHORS.md) file.

## Contribute!

Please consider contributing, either by [reporting issues](https://framagit.org/luc/lutim/issues) or by helping the [internationalization](https://pootle.framasoft.org/projects/lutim/). And of course, code contribution are welcome!

The details on how to contribute are on the [wiki](https://framagit.org/luc/lutim/wikis/contribute).

## Make a donation

You can make a donation to the author on [Tipeee](https://www.tipeee.com/fiat-tux) or on [Liberapay](https://liberapay.com/sky/).

## Others projects dependencies

Lutim is written in Perl with the [Mojolicious](http://mojolicio.us) framework.

It uses:

* [Twitter bootstrap](http://getbootstrap.com) framework to look not too ugly
* [JQuery](http://jquery.com) and [JQuery File Uploader](https://github.com/danielm/uploader/) (slightly modified) to add some modernity
* [Raphaël](http://raphaeljs.com/) and [morris.js](https://morrisjs.github.io/morris.js/) for stats graphs
* [freezeframe.js](http://freezeframe.chrisantonellis.com/) (slightly modified) to be able to freeze animated gifs in twitter card
* [Moment.js](http://momentjs.com/) for displaying real dates instead of unix timestamps.
* [Fontello](http://fontello.com/) and the [markdown font](https://github.com/dcurtis/markdown-mark/) for the icons, licenses for the fontello icons fonts are in `public/font/LICENSE.txt`
* [Henny Penny](https://www.google.com/fonts/specimen/Henny+Penny) font designed by Olga Umpeleva for [Brownfox](http://brownfox.org)
* [Unite gallery](http://unitegallery.net/) for the gallery
* [JSZip](https://stuk.github.io/jszip/) for generating a zip containing all the images in the gallery
* [FileSaver.js](https://github.com/eligrey/FileSaver.js/) for saving the zip
