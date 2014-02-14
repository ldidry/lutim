#LUTIm

##What LUTIm means?
It means Let's Upload That Image.

##What does it do?
It stores images and allows you to see them or download them.
Images are indefinitly stored unless you request that they will be deleted at first view or after 24 hours.

##License
LUTIm is licensed under the terms of the AGPL. See the LICENSE file.

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
```

##Usage
```
carton exec hypnotoad script/lutim
```

Yup, that's all, it will listen at "http://127.0.0.1:8080".

For more options (interfaces, user, etc.), change the configuration in `lutim.conf` (have a look at http://mojolicio.us/perldoc/Mojo/Server/Hypnotoad#SETTINGS for the available options).

##Reverse proxy
You can use a reverse proxy like Nginx or Varnish (or Apache with the mod\_proxy module). The web is full of tutos.

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
LUTIm is written in Perl with the Mojolicious framework, uses the Twitter bootstrap framework to look not too ugly, JQuery and JQuery File Uploader (<https://github.com/danielm/uploader/>) to add some modernity.

##Official instance
You can see it working at http://lut.im.
