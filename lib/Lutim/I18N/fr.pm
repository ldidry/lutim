package Lutim::I18N::fr;
use Mojo::Base 'Lutim::I18N';

my $inf_body = <<EOF;
<h4>Qu’est-ce que LUTIm ?</h4>
<p>LUTIm est un service gratuit et anonyme d’hébergement d’images. Il s’agit aussi du nom du logiciel (libre) qui fournit ce service.</p>
<p>Les images déposées sur LUTIm peuvent être stockées indéfiniment, ou s’effacer dès le premier affichage ou au bout de 24h.</p>
<h4>Comment ça marche ?</h4>
<p>Faites glisser des images dans la zone prévue à cet effet ou sélectionnez un fichier de façon classique et LUTIm vous fournira deux URLs en retour. Une pour afficher l’image, l’autre pour la télécharger directement.</p>
<p>Vous pouvez, de façon facultative, demander à ce que la ou les images déposées sur LUTIm soient supprimées après leur premier affichage (ou téléchargement) ou au bout de 24 heures.</p>
<h4>C’est vraiment gratuit ?</h4>
<p>Oui, ça l’est ! Par contre, si vous avez envie de soutenir le développeur, vous pouvez faire un microdon avec <a href="https://flattr.com/submit/auto?user_id=_SKy_&amp;url=[_1]&amp;title=LUTIm&amp;category=software">Flattr</a> ou en <a href="bitcoin:1K3n4MXNRSMHk28oTfXEvDunWFthePvd8v?label=lutim">BitCoin</a>.</p>
<h4>C’est vraiment anonyme ?</h4>
<p>Oui, ça l’est ! Par contre, pour des raisons légales, votre adresse IP sera enregistrée lorsque vous enverrez une image. Ne vous affolez pas, c’est de toute façon normalement le cas de tous les sites sur lesquels vous envoyez des fichiers !</p>
<p>L’IP de la personne ayant déposé l’image est stockée de manière définitive.</p>
<p>Si les fichiers sont bien supprimés si vous en avez exprimé le choix, leur empreinte SHA512 est toutefois conservée.</p>
<h4>Comment peut-on faire pour signaler une image ?</h4>
<p>Veuillez contacter l’administrateur : [_2]</p>
<h4>Comment doit-on prononcer LUTIm ?</h4>
<p>Comme on prononce <a href="https://fr.wikipedia.org/wiki/Lutin">lutin</a> !</p>
<h4>Et à propos du logiciel qui fournit le service ?</h4>
<p>Le logiciel LUTIm est un <a href="https://fr.wikipedia.org/wiki/Logiciel_libre">logiciel libre</a>, ce qui vous permet de le télécharger et de l’installer sur votre propre serveur. Jetez un coup d’œil à l’<a href="https://www.gnu.org/licenses/agpl-3.0.html">AGPL</a> pour voir quels sont vos droits.</p>
<p>Pour plus de détails, consultez la page <a href="https://github.com/ldidry/lutim">Github</a> du projet.</p>
EOF

our %Lexicon = (
    'license'               => 'Licence :',
    'fork-me'               => 'Fork me on Github',
    'share-twitter'         => 'Partager sur Twitter',
    'informations'          => 'Informations',
    'informations-body'     => $inf_body,
    'view-link'             => 'Lien d\'affichage :',
    'download-link'         => 'Lien de téléchargement :',
    'twitter-link'          => 'Lien pour mettre dans un tweet :',
    'some-bad'              => 'Un problème est survenu',
    'delete-first'          => 'Supprimer au premier accès ?',
    'delete-day'            => 'Supprimer après 24 heures ?',
    'upload_image'          => 'Envoyez une image',
    'image-only'            => 'Seules les images sont acceptées',
    'go'                    => 'Allons-y !',
    'drag-n-drop'           => 'Déposez vos images ici',
    'or'                    => '-ou-',
    'file-browser'          => 'Cliquez pour utiliser le navigateur de fichier',
    'image_not_found'       => 'Impossible de trouver l\'image',
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
    'lutim-stats'           => 'Statistiques de LUTIm',
    'back-to-index'         => 'Retour à la page d\'accueil',
    'stop_upload'           => 'L\'envoi d\'images est actuellement désactivé, veuillez réessayer plus ou contacter l\'administrateur ([_1]).',
);

1;
