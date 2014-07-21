package Lutim::I18N::en;
use Mojo::Base 'Lutim::I18N';

my $inf_body = <<EOF;
<h4>What is Lutim?</h4>
<p>Lutim is a free (as in free beer) and anonymous image hosting service. It's also the name of the free (as in free speech) software which provides this service.</p>
<p>The images you post on Lutim can be stored indefinitely or be deleted at first view or after a delay selected from those proposed.</p>
<h4>How does it work?</h4>
<p>Drag and drop an image in the appropriate area or use the traditional way to send files and Lutim will provide you three URLs. One to view the image, an other to directly download it an a last which you can use in Twitter.</p>
<p>You can, optionally, request that the image(s) posted on Lutim to be deleted at first view (or download) or after the delay selected from those proposed.</p>
<h4>Is it really free (as in free beer)?</h4>
<p>Yes, it is! On the other side, if you want to support the developer, you can do it via <a href="https://flattr.com/submit/auto?user_id=_SKy_&amp;url=[_1]&amp;title=Lutim&amp;category=software">Flattr</a> or with <a href="bitcoin:1K3n4MXNRSMHk28oTfXEvDunWFthePvd8v?label=lutim">BitCoin</a>.</p>
<h4>Is it really anonymous?</h4>
<p>Yes, it is! On the other side, for legal reasons, your IP address will be stored when you send an image. Don't panic, it is normally the case of all sites on which you send files!</p>
<p>The IP address of the image's sender is retained for a delay which depends of the administrator's choice (for the official instance, which is located in France, it's one year).</p>
<p>If the files are deleted if you ask it while posting it, their SHA512 footprint are retained.</p>
<h4>How to report an image?</h4>
<p>Please contact the administrator: [_2]</p>
<h4>How do you pronounce Lutim?</h4>
<p>Juste like you pronounce the French word <a href="https://fr.wikipedia.org/wiki/Lutin">lutin</a> (/ly.tɛ̃/).</p>
<h4>What about the software which provides the service?</h4>
<p>The Lutim software is a <a href="http://en.wikipedia.org/wiki/Free_software">free software</a>, which allows you to download and install it on you own server. Have a look at the <a href="https://www.gnu.org/licenses/agpl-3.0.html">AGPL</a> to see what you can do.</p>
<p>For more details, see the <a href="https://github.com/ldidry/lutim">Github</a> page of the project.</p>
<h4>Main developers</h4>
<ul>
    <li>Luc Didry, aka Sky (<a href="http://www.fiat-tux.fr">http://www.fiat-tux.fr</a>), core developer, <a href="https://twitter.com/framasky">\@framasky</a></li>
    <li>Dattaz (<a href="http://dattaz.fr">http://dattaz.fr</a>), webapp developer, <a href="https://twitter.com/dat_taz">\@dat_taz</a></li>
</ul>
<h4>Contributors</h4>
<ul>
    <li>Jean-Bernard Marcon, aka Goofy (<a href="https://github.com/goofy-bz">https://github.com/goofy-bz</a>)</li>
    <li>Jean-Christophe Bach (<a href="https://github.com/jcb">https://github.com/jcb</a>)</li>
    <li>Florian Bigard, aka Chocobozzz (<a href="https://github.com/Chocobozzz">https://github.com/Chocobozzz</a>)</li>
    <li>Sandro CAZZANIGA, aka Kharec (<a href="http://sandrocazzaniga.fr">http://sandrocazzaniga.fr</a>), <a href="https://twitter.com/Kharec">\@Kharec</a></li>
</ul>
EOF

our %Lexicon = (
    'homepage'              => 'Homepage',
    'license'               => 'License:',
    'fork-me'               => 'Fork me on Github !',
    'share-twitter'         => 'Share on Twitter',
    'informations'          => 'Informations',
    'informations-body'     => $inf_body,
    'view-link'             => 'View link',
    'download-link'         => 'Download link',
    'twitter-link'          => 'Link for put in a tweet',
    'tweet_it'              => 'Tweet it!',
    'share_it'              => 'Share it!',
    'delete-link'           => 'Deletion link',
    'some-bad'              => 'Something bad happened',
    'delete-first'          => 'Delete at first view?',
    'delete-day'            => 'Delete after 24 hours?',
    'upload_image'          => 'Send an image',
    'image-only'            => 'Only images are allowed',
    'go'                    => 'Let\'s go!',
    'drag-n-drop'           => 'Drag & drop images here',
    'or'                    => '-or-',
    'file-browser'          => 'Click to open the file browser',
    'image_not_found'       => 'Unable to find the image: it has been deleted.',
    'no_more_short'         => 'There is no more available URL. Retry or contact the administrator. [_1]',
    'no_valid_file'         => 'The file [_1] is not an image.',
    'file_too_big'          => 'The file exceed the size limit ([_1])',
    'no_time_limit'         => 'No time limit',
    '24_hours'              => '24 hours',
    '7_days'                => '7 days',
    '30_days'               => '30 days',
    '1_year'                => 'One year',
    'pushed-images'         => ' sent images on this instance from beginning.',
    'graph-data-once-a-day' => 'The graph\'s datas are not updated in real-time.',
    'lutim-stats'           => 'Lutim\'s statistics',
    'back-to-index'         => 'Back to homepage',
    'stop_upload'           => 'Uploading is currently disabled, please try later or contact the administrator ([_1]).',
    'download_error'        => 'An error occured while downloading the image.',
    'no_valid_url'          => 'The URL is not valid.',
    'image_url'             => 'Image URL',
    'upload_image_url'      => 'Upload an image with its URL',
    'delay_0'               => 'no time limit',
    'delay_1'               => '24 hours',
    'delay_days'            => '[_1] days',
    'delay_365'             => '1 year',
    'max_delay'             => 'Warning! The maximum time limit for an image is [_1] day(s), even if you choose "no time limit".',
    'crypt_image'           => 'Encrypt the image (Lutim does not keep the key).',
    'always_encrypt'        => 'The images are encrypted on the server (Lutim does not keep the key).',
    'image_deleted'         => 'The image [_1] has been successfully deleted',
    'invalid_token'         => 'The delete token is invalid.',
    'already_deleted'       => 'The image [_1] has already been deleted.',
    'install_as_webapp'     => 'Install webapp',
    'image_delay_modified'  => 'The image\'s delay has been successfully modified',
    'image_mod_not_found'   => 'Unable to find the image [_1].',
    'modify_image_error'    => 'Error while trying to modify the image.',
);

1;
