#LUTIm

##What LUTIm means?
It means Let's Upload That Image.

##What does it do?
It stores images and allows you to see them or download them.
Images are indefinitly stored unless you request that they will be deleted at first view or after 24 hours.

##License
LUTIm is licensed under the terms of the AGPL. See the LICENSE file.

##Logo
LUTIm's logo is an adaptation of [Lutin](http://commons.wikimedia.org/wiki/File:Lutin_by_godo.jpg) by [Godo](http://godoillustrateur.wordpress.com/), licensed under the terms of the CC-BY-SA 3.0 license.

![LUTIm's logo](http://lut.im/img/LUTIm_small.png)

##Dependancies
* Carton : Perl dependancies manager, it will get what you need, so don't bother for dependancies (but you can read the file `cpanfile` if you want).

```shell
sudo cpan Carton
```

##Installation
After installing Carton :
```shell
git clone https://github.com/ldidry/lutim.git
cd lutim
carton install
cp lutim.conf.template lutim.conf
vi lutim.conf
```

##Configuration
* hypnotoad: listen to listen to, user and group which runs hypnotoad ;
* contact: write something which make people able to contact you (contact form URL, email address, whatever) ;
* secrets: an array of random string. Used by Mojolicious for encrypting session cookies.
* piwik\_img: the image Piwik provides you to have records of visits without javascript (better privacy than js and cookies) ;
* length: length of the random string part of image's URL (default is 8) ;
* provis\_step: LUTIm provisions random strings for image's URL per pack of `provis_step` (default is 5) ;
* provisioning: number of random strings to provision (default is 100) ;
* hosted\_by: if someone hosts your LUTIm instance, you can add some HTML (a logo for example) to make it appear on index page ;
* tweet\_card\_via: a twitter account which will appear on twitter cards ;
* max\_file\_size: well, this is explicit (default is 10Mio = 10485760 octets) ;
* https: 1 if you want to provide secure images URLs (default is 0) ;
* stats\_day\_num: when you generate statistics with `script/lutim cron stats`, you will have stats for the last `stats_day_num` days (default is 365) ;
* keep\_ip\_during: when you delete IP addresses of image's senders with `script/lutim cron cleanbdd`, the IP addresses of images older than `keep_ip_during` days will be deleted (default is 365) ;

##Usage
```
carton exec hypnotoad script/lutim
```

##Update
```
git pull
carton install
carton exec hypnotoad script/lutim
```

Yup, that's all (Mojolicious magic), it will listen at "http://127.0.0.1:8080".

For more options (interfaces, user, etc.), change the configuration in `lutim.conf` (have a look at http://mojolicio.us/perldoc/Mojo/Server/Hypnotoad#SETTINGS for the available options).

##Reverse proxy
You can use a reverse proxy like Nginx or Varnish (or Apache with the mod\_proxy module). The web is full of tutos.

Here's a valid *Varnish* configuration:
```
backend lutim {
    .host = "127.0.0.1";
    .port = "8080";
}
sub vcl_recv {
    if (req.restarts == 0) {
        set req.http.X-Forwarded-For = client.ip;
    }
    if (req.http.host == "lut.im") {
        set req.backend = lutim;
        return(pass);
    }
}
```

##Cron jobs
LUTIm have commands which can be used in cron jobs.

To see what commands are available:
```shell
carton exec script/lutim cron
```

###Statistics
To generate statistics which can be viewed at the address `/stats`:
```shell
carton exec script/lutim cron stats
```

###Delete IP adresses from database
To automatically delete the IP addresses of image's senders after a configurable delay:
```shell
carton exec script/lutim cron cleanbdd
```


##Shutter integration
See where Shutter (<http://en.wikipedia.org/wiki/Shutter_%28software%29>) keeps its plugins on your computer.
On my computer, it's in `/usr/share/shutter/resources/system/upload_plugins/upload`.

Then:
```
sudo cp utilities/Shutter.pm /usr/share/shutter/resources/system/upload_plugins/upload/Lutim.pm
```

And restart Shutter if it was running.

Of course, this plugin is configured for the official instance of LUTIm (<http://lut.im>), feel free to edit it for your own instance.

##Internationalization
LUTIm comes with english and french languages. It will choose the language to display from the browser's settings.

If you want to add more languages, for example german:
```shell
cd lib/I18N
cp en.pm de.pm
vim de.pm
```

There's just a few sentences, so it will be quick to translate. Please consider to send me you language file in order to help the other users :smile:.

##Others projects dependancies
LUTIm is written in Perl with the [Mojolicious](http://mojolicio.us) framework, uses the [Twitter bootstrap](http://getbootstrap.com) framework to look not too ugly, [JQuery](http://jquery.com) and [JQuery File Uploader](https://github.com/danielm/uploader/) (slightly modified) to add some modernity, [Raphaël](http://raphaeljs.com/) and [SimpleGraph](http://benaskins.github.io/simplegraph/) for stats graphs.

##Official instance
You can see it working at http://lut.im.
