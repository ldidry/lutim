package Lutim::I18N::en;
use Mojo::Base 'Lutim::I18N';

my $inf_body = <<EOF;
<h4>What is LUTIm?</h4>
<p>LUTIm is a free (as in free beer) and anonymous image hosting service. It's also the name of the free (as in free speech) software which provides this service.</p>
<p>The images you post on LUTIm can be stored indefinitely or be deleted at first view or after 24 hours.</p>
<h4>How does it work?</h4>
<p>Drag and drop an image in the appropriate area or use the traditional way to send files and LUTIm will provide you two URLs. One to view the image, the other to directly download it.</p>
<p>You can, optionally, request that the image(s) posted on LUTIm to be deleted at first view (or download) or after 24 hours.</p>
<h4>Is it really free (as in free beer)?</h4>
<p>Yes, it is! On the other side, if you want to support the developer, you can do it via <a href="https://flattr.com/submit/auto?user_id=_SKy_&url=[_1]&title=LUTIm&category=software">Flattr</a> or with <a href="bitcoin:1K3n4MXNRSMHk28oTfXEvDunWFthePvd8v?label=lutim">BitCoin</a>.</p>
<h4>Is it really anonymous?</h4>
<p>Yes, it is! On the other side, for legal reasons, your IP address will be stored when you send or view an image. Don't panic, it is the case of all sites on which you go!</p>
<p>The log files containing the IP address of image viewers are retained for one year while the IP address of the image's sender, as the address of the last viewer are permanently retained.</p>
<p>If the files are deleted if you ask it while posting it, their SHA512 footprint are retained.</p>
<h4>How to report an image?</h4>
<p>Please contact the administrator: [_2]</p>
<h4>How do you pronounce LUTIm?</h4>
<p>Juste like you pronounce the French word <a href="https://fr.wikipedia.org/wiki/Lutin">lutin</a> (/ly.tɛ̃/).</p>
<h4>What about the software which provides the service?</h4>
<p>The LUTIm software is a <a href="http://en.wikipedia.org/wiki/Free_software">free software</a>, which allows you to download and install it on you own server. Have a look at the <a href="https://www.gnu.org/licenses/agpl-3.0.html">AGPL</a> to see what you can do.</p>
<p>For more details, see the <a href="https://github.com/ldidry/lutim">Github</a> page of the project.</p>
EOF

our %Lexicon = (
    'license'           => 'License:',
    'fork-me'           => 'Fork me on Github !',
    'share-twitter'     => 'Share on Twitter',
    'informations'      => 'Informations',
    'informations-body' => $inf_body,
    'view-link'         => 'View link:',
    'download-link'     => 'Download link:',
    'twitter-link'      => 'Link for put in a tweet:',
    'some-bad'          => 'Something bad happened',
    'delete-first'      => 'Delete at first view?',
    'delete-day'        => 'Delete after 24 hours?',
    'upload_image'      => 'Send an image',
    'image-only'        => 'Only images are allowed',
    'go'                => 'Let\'s go!',
    'drag-n-drop'       => 'Drag & drop images here',
    'or'                => '-or-',
    'file-browser'      => 'Click to open the file browser',
    'image_not_found'   => 'Unable to find the image',
    'no_more_short'     => 'There is no more available URL. Retry or contact the administrator. [_1]',
    'no_valid_file'     => 'The file [_1] is not an image.',
);

1;
