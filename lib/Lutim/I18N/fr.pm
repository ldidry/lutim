package Lutim::I18N::fr;
use Mojo::Base 'Lutim::I18N';

my $inf_body = <<EOF;
<h4>Qu’est-ce que Lutim ?</h4>
<p>Lutim est un service gratuit et anonyme d’hébergement d’images. Il s’agit aussi du nom du logiciel (libre) qui fournit ce service.</p>
<p>Les images déposées sur Lutim peuvent être stockées indéfiniment, ou s’effacer dès le premier affichage ou au bout du délai choisi parmi ceux proposés.</p>
<h4>Comment ça marche ?</h4>
<p>Faites glisser des images dans la zone prévue à cet effet ou sélectionnez un fichier de façon classique et Lutim vous fournira troie URLs en retour. Une pour afficher l’image, une autre pour la télécharger directement et une dernière utilisable sur Twitter.</p>
<p>Vous pouvez, de façon facultative, demander à ce que la ou les images déposées sur Lutim soient supprimées après leur premier affichage (ou téléchargement) ou au bout d'un délai choisi parmi ceux proposés.</p>
<h4>C’est vraiment gratuit ?</h4>
<p>Oui, ça l’est ! Par contre, si vous avez envie de soutenir le développeur, vous pouvez faire un microdon avec <a href="https://flattr.com/submit/auto?user_id=_SKy_&amp;url=[_1]&amp;title=Lutim&amp;category=software">Flattr</a> ou en <a href="bitcoin:1K3n4MXNRSMHk28oTfXEvDunWFthePvd8v?label=lutim">BitCoin</a>.</p>
<h4>C’est vraiment anonyme ?</h4>
<p>Oui, ça l’est ! Par contre, pour des raisons légales, votre adresse IP sera enregistrée lorsque vous enverrez une image. Ne vous affolez pas, c’est de toute façon normalement le cas de tous les sites sur lesquels vous envoyez des fichiers !</p>
<p>L’IP de la personne ayant déposé l’image est stockée pendant un délai dépendant de l'administrateur de l'instance (pour l'instance officielle, dont le serveur est en France, c'est un délai d'un an).</p>
<p>Si les fichiers sont bien supprimés si vous en avez exprimé le choix, leur empreinte SHA512 est toutefois conservée.</p>
<h4>Comment peut-on faire pour signaler une image ?</h4>
<p>Veuillez contacter l’administrateur : [_2]</p>
<h4>Comment doit-on prononcer Lutim ?</h4>
<p>Comme on prononce <a href="https://fr.wikipedia.org/wiki/Lutin">lutin</a> !</p>
<h4>Et à propos du logiciel qui fournit le service ?</h4>
<p>Le logiciel Lutim est un <a href="https://fr.wikipedia.org/wiki/Logiciel_libre">logiciel libre</a>, ce qui vous permet de le télécharger et de l’installer sur votre propre serveur. Jetez un coup d’œil à l’<a href="https://www.gnu.org/licenses/agpl-3.0.html">AGPL</a> pour voir quels sont vos droits.</p>
<p>Pour plus de détails, consultez la page <a href="https://github.com/ldidry/lutim">Github</a> du projet.</p>
<h4>Développeurs de l'application</h4>
<ul>
    <li>Luc Didry, aka Sky (<a href="http://www.fiat-tux.fr">http://www.fiat-tux.fr</a>), développeur principal, <a href="https://twitter.com/framasky">\@framasky</a></li>
    <li>Dattaz (<a href="http://dattaz.fr">http://dattaz.fr</a>), développeur de la webapp, <a href="https://twitter.com/dat_taz">\@dat_taz</a></li>
</ul>
<h4>Contributeurs</h4>
<ul>
    <li>Jean-Bernard Marcon, aka Goofy (<a href="https://github.com/goofy-bz">https://github.com/goofy-bz</a>)</li>
    <li>Jean-Christophe Bach (<a href="https://github.com/jcb">https://github.com/jcb</a>)</li>
    <li>Florian Bigard, aka Chocobozzz (<a href="https://github.com/Chocobozzz">https://github.com/Chocobozzz</a>)</li>
    <li>Sandro CAZZANIGA, aka Kharec (<a href="http://sandrocazzaniga.fr">http://sandrocazzaniga.fr</a>), <a href="https://twitter.com/Kharec">\@Kharec</a></li>
</ul>
EOF

our %Lexicon = (
    'homepage'              => 'Accueil',
    'license'               => 'Licence :',
    'fork-me'               => 'Fork me on Github',
    'share-twitter'         => 'Partager sur Twitter',
    'informations'          => 'Informations',
    'informations-body'     => $inf_body,
    'view-link'             => 'Lien d\'affichage',
    'download-link'         => 'Lien de téléchargement',
    'twitter-link'          => 'Lien pour mettre dans un tweet',
    'tweet_it'              => 'Tweetez !',
    'share_it'              => 'Partagez !',
    'delete-link'           => 'Lien de suppression',
    'some-bad'              => 'Un problème est survenu',
    'delete-first'          => 'Supprimer au premier accès ?',
    'delete-day'            => 'Supprimer après 24 heures ?',
    'upload_image'          => 'Envoyez une image',
    'image-only'            => 'Seules les images sont acceptées',
    'go'                    => 'Allons-y !',
    'drag-n-drop'           => 'Déposez vos images ici',
    'or'                    => '-ou-',
    'file-browser'          => 'Cliquez pour utiliser le navigateur de fichier',
    'image_not_found'       => 'Impossible de trouver l\'image : elle a été supprimée.',
    'no_more_short'         => 'Il n\'y a plus d\'URL disponible. Veuillez réessayer ou contactez l\'administrateur. [_1].',
    'no_valid_file'         => 'Le fichier [_1] n\'est pas une image.',
    'file_too_big'          => 'Le fichier dépasse la limite de taille ([_1])',
    'no_time_limit'         => 'Pas de limitation de durée',
    '24_hours'              => '24 heures',
    '7_days'                => '7 jours',
    '30_days'               => '30 jours',
    '1_year'                => 'Un an',
    'pushed-images'         => ' images envoyées sur cette instance depuis le début.',
    'graph-data-once-a-day' => 'Les données du graphique ne sont pas mises à jour en temps réél.',
    'lutim-stats'           => 'Statistiques de Lutim',
    'back-to-index'         => 'Retour à la page d\'accueil',
    'stop_upload'           => 'L\'envoi d\'images est actuellement désactivé, veuillez réessayer plus tard ou contacter l\'administrateur ([_1]).',
    'download_error'        => 'Une erreur est survenue lors du téléchargement de l\'image.',
    'no_valid_url'          => 'l\'URL n\'est pas valide.',
    'image_url'             => 'URL de l\'image',
    'upload_image_url'      => 'Déposer une image par son URL',
    'delay_0'               => 'pas de limitation de durée',
    'delay_1'               => '24 heures',
    'delay_days'            => '[_1] jours',
    'delay_365'             => '1 an',
    'max_delay'             => 'Attention ! Le délai maximal de rétention d\'une image est de [_1] jour(s), même si vous choisissez « pas de limitation de durée ».',
    'crypt_image'           => 'Chiffrer l\'image (Lutim ne stocke pas la clé).',
    'always_encrypt'        => 'Les images sont chiffrées sur le serveur (Lutim ne stocke pas la clé).',
    'image_deleted'         => 'L\'image [_1] a été supprimée avec succès.',
    'invalid_token'         => 'Le jeton de suppression est invalide.',
    'already_deleted'       => 'L\'image [_1] a déjà été supprimée.',
    'install_as_webapp'     => 'Installer la webapp',
    'image_delay_modified'  => 'Le délai de l\'image a été modifié avec succès.',
    'image_mod_not_found'   => 'Impossible de trouver l\'image [_1].',
    'modify_image_error'    => 'Une erreur est survenue lors de la tentative de modification de l\'image.',
);

1;
