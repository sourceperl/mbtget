#!/usr/bin/perl -w

# Client ModBus/TCP de classe 1
#     Version: 1.2.0
#    Site web: http://source.perl.free.fr
#        Date: 12/04/2012
#     License: GPL (www.gnu.org)
# Description: Client ModBus/TCP en ligne de commande
#              Support des fonctions 3 et 16 (classe 0)
#                                    1,2,4,5,6 (classe 1)

# changelog
# ajout 1.2.0: modification des entêtes pour publication du code source
# ajout 1.1.4: ajout \- à l'expression régulière hostname (pour gestion des hôtes telle que "exp-1.dom")

# TODO: fonctions 1,2,3 and 4: vérifier le nombre de mots reçu
# TODO: intégration documentation au format POD dans le code source

use strict;
use Socket;

# Constantes mbget
my $MBGET_VERSION            = '1.2.0';
my $MBGET_USAGE              =
'usage : mbtget [-hvdsf]
               [-u unit_id] [-a adresse] [-n nombre_de_valeur]
               [-r[12347]] [-w5 bit_value] [-w6 word_value]
               [-p port] [-t timeout] serveur

Options de la ligne de commande :
  -h                    : affichage de l\'aide
  -v                    : affichage du numéro de version
  -d                    : active le mode "dump" (affiche le contenu des trames)
  -s                    : active le mode "script" (sortie csv sur stdout)
  -r1                   : lecture de bit(s) (fonction 1)
  -r2                   : lecture de bit(s) (fonction 2)
  -r3                   : lecture de mot(s) (fonction 3)
  -r4                   : lecture de mot(s) (fonction 4)
  -w5 bit_value         : écriture d\'un bit (fonction 5)
  -w6 word_value        : écriture d\'un registre (fonction 6)
  -r7                   : lecture du statut d\'exception
  -f                    : affichage des mots en virgule flottante
  -hex                  : affichage des valeurs en hexadécimal
  -u unit_id            : permet de spécifier un "unit id"
  -p port_number        : permet de spécifier un port TCP différent de 502
  -a modbus_address     : permet de spécifier l\'adresse ModBus à lire
  -n value_number       : nombre de valeur à lire
  -t timeout            : valeur de timeout (en s)';

# Paramètres ModBus/TCP
my $MODBUS_PORT                                 = 502;
# Codes fonctions
my $READ_COILS                                  = 0x01;
my $READ_DISCRETE_INPUTS                        = 0x02;
my $READ_HOLDING_REGISTERS                      = 0x03;
my $READ_INPUT_REGISTERS                        = 0x04;
my $WRITE_SINGLE_COIL                           = 0x05;
my $WRITE_SINGLE_REGISTER                       = 0x06;
# Codes exceptions
my $EXP_ILLEGAL_FUNCTION                        = 0x01;
my $EXP_DATA_ADDRESS                            = 0x02;
my $EXP_DATA_VALUE                              = 0x03;
my $EXP_SLAVE_DEVICE_FAILURE                    = 0x04;
my $EXP_ACKNOWLEDGE                             = 0x05;
my $EXP_SLAVE_DEVICE_BUSY                       = 0x06;
my $EXP_MEMORY_PARITY_ERROR                     = 0x08;
my $EXP_GATEWAY_PATH_UNAVAILABLE                = 0x0A;
my $EXP_GATEWAY_TARGET_DEVICE_FAILED_TO_RESPOND = 0x0B;

# Valeurs par défaut
my $opt_server                                  = 'localhost';
my $opt_server_port                             = $MODBUS_PORT;
my $opt_timeout                                 = 5;
my $opt_dump_mode                               = 0;
my $opt_script_mode                             = 0;
my $opt_unit_id                                 = 1;
my $opt_mb_fc                                   = $READ_HOLDING_REGISTERS;
my $opt_mb_ad                                   = 0;
my $opt_mb_nb                                   = 1;
my $opt_bit_value                               = 0;
my $opt_word_value                              = 0;
my $opt_ieee                                    = 0;
my $opt_hex_ad                                  = 0;
my $opt_hex_value                               = 0;

# *** Analyse des arguments de ligne de commande ***
while(defined($_ = shift @ARGV)) {
  /^-h$/   and do {print $MBGET_USAGE."\n"; exit 0;};
  /^-v$/   and do {print 'version: '.$MBGET_VERSION."\n"; exit 0;};
  /^-d$/   and do {$opt_dump_mode = 1; next;};
  /^-s$/   and do {$opt_script_mode = 1; next;};
  /^-f$/   and do {$opt_ieee = 1; next;};
  /^-hex$/ and do {$opt_hex_value = 1; next;};
  /^-r1$/  and do {$opt_mb_fc = $READ_COILS; next;};
  /^-r2$/  and do {$opt_mb_fc = $READ_DISCRETE_INPUTS; next;};
  /^-r3$/  and do {$opt_mb_fc = $READ_HOLDING_REGISTERS; next;};
  /^-r4$/  and do {$opt_mb_fc = $READ_INPUT_REGISTERS; next;};
  ## valeur du bit (pour fonction 5)
  /^-w5$/  and do {
    $opt_mb_fc = $WRITE_SINGLE_COIL;
    $_ = shift @ARGV;
    if (($_ eq '0') || ($_ eq '1')) {
      $opt_bit_value = $_; next;
    } else {
      print STDERR 'option "-w5": bit_value = 0 or 1'."\n";
      exit 1;
    }
  };
  ## valeur du mot (pour fonction 6)
  /^-w6$/  and do {
    $opt_mb_fc = $WRITE_SINGLE_REGISTER;
    $_ = shift @ARGV;
    if ((/^\d{1,5}$/) && ($_ <= 65535) && ($_ >= 0)) {
      $opt_word_value = $_; next;
    } elsif ((/^0x[a-fA-F0-9]{1,4}$/) && (hex($_) >= 0)) {
      $opt_word_value = hex($_); next;
    } else {
      print STDERR 'option "-w6": 0 <= word_value <= 65535'."\n";
      exit 1;
    }
  };
  ## unit id
  /^-u$/  and do {
    $_ = shift @ARGV;
    if ((/^\d{1,3}$/) && ($_ <= 255) && ($_ > 0)) {
      $opt_unit_id = $_; next;
    } elsif ((/^0x[a-fA-F0-9]{1,2}$/) && (hex($_) > 0)) {
      $opt_unit_id = hex($_); next;
    } else {
      print STDERR 'option "-u": 1 <= unit_id <= 255'."\n";
      exit 1;
    }
  };
  ## port tcp du serveur
  /^-p$/ and do {
    $_ = shift @ARGV;
    if ((/^\d{1,5}$/) && ($_ <= 65535) && ($_ > 0)) {
      $opt_server_port = $_; next;
    } elsif ((/^0x[a-fA-F0-9]{1,4}$/) && (hex($_) > 0)) {
      $opt_server_port = hex($_); next;
    } else {
      print STDERR 'option "-p": 1 <= port_number <= 65535.'."\n";
      exit 1;
    }
  };
  ## adresse modbus
  /^-a$/ and do {
    $_ = shift @ARGV;
    if ((/^\d{1,5}$/) && ($_ <= 65535)) {
      $opt_mb_ad = $_; next;
    } elsif ((/^0x[a-fA-F0-9]{1,4}$/)) {
      $opt_mb_ad = hex($_);
      $opt_hex_ad = 1;
      next;
    }else {
      print STDERR 'option "-a": 0 <= modbus_address <= 65535'."\n";
      exit 1;
    }
  };
  ## nombre de valeur
  /^-n$/ and do {
    $_ = shift @ARGV;
    if ((/^\d{1,3}$/) && ($_ <= 125) && ($_ > 0)) {
      $opt_mb_nb = $_; next;
    } elsif ((/^0x[a-fA-F0-9]{1,2}$/) && (hex($_) <= 125) && (hex($_) > 0)) {
      $opt_mb_nb = hex($_); next;
    } else {
      print STDERR 'option "-n": 1 <= value_number <= 125'."\n";
      exit 1;
    }
  };
  ## valeur du timeout (en s)
  /^-t$/ and do {
    $_ = shift @ARGV;
    if (/^\d{1,3}$/ && ($_ < 120) && ($_ > 0)) {
      $opt_timeout = $_;
      next;
    } else {
      print STDERR 'option "-t": timeout < 120s'."\n";
      exit 1;
    }
  };
  ## nom ou ip du serveur
  (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/ or /^[a-z][a-z0-9\.\-]+$/) and do {
    $opt_server = $_;
    next;
  };
  ## option invalide
  /^.*$/ and do {
    print STDERR 'invalid option "'.$_.'" (use -h for help)'."\n";
    exit 1;
  };
} # Fin de l'analyse de la ligne de commande

# *** Gestion des dépendances (après analyse de ligne de commande) ***
# En mode IEEE 1 variable = 2 mots de 16 bits
if ($opt_ieee) {
  if (($opt_mb_nb *= 2) > 125) {
    print STDERR 'option "-n" and "-f": 1 <= nb_var <= 62'."\n";
    exit 1;
  }
  if (!(($opt_mb_fc == $READ_HOLDING_REGISTERS)
     || ($opt_mb_fc == $READ_INPUT_REGISTERS))) {
      print STDERR 'option "-f": incompatible with function '.$opt_mb_fc."\n";
      exit 1;
  }
}
# Résolution DNS
my $server_ip = inet_aton($opt_server);
if (!$server_ip) {
  print STDERR 'unable to resolve "'.$opt_server.'"'."\n";
  exit 1;
}

# *** Gestion du dialogue reseau ***
# Ouverture de la session TCP
socket(SERVER, PF_INET, SOCK_STREAM, getprotobyname('tcp'));
connect(SERVER, sockaddr_in($opt_server_port, $server_ip))
or do {
  print STDERR 'connexion au serveur "'.$opt_server.':'.
               $opt_server_port.'" impossible'."\n";
  exit 2;
};
# Construction de la requête
# header
my $tx_buffer;
my $tx_hd_tr_id   = int(rand 65535);
my $tx_hd_pr_id   = 0;
my $tx_hd_length;
my $tx_hd_unit_id = $opt_unit_id;
# body
my $tx_bd_fc      = $opt_mb_fc;
my $tx_bd_ad      = $opt_mb_ad;
## Trames de lecture bit/mot
if (($opt_mb_fc == $READ_COILS) ||
    ($opt_mb_fc == $READ_DISCRETE_INPUTS) ||
    ($opt_mb_fc == $READ_HOLDING_REGISTERS) ||
    ($opt_mb_fc == $READ_INPUT_REGISTERS)) {
  $tx_hd_length  = 6;
  my $tx_bd_nb  = $opt_mb_nb;
  $tx_buffer = pack("nnnCCnn", $tx_hd_tr_id, $tx_hd_pr_id,
                               $tx_hd_length, $tx_hd_unit_id,
                               $tx_bd_fc, $tx_bd_ad, $tx_bd_nb);
## Trame d'écriture d'un bit
} elsif ($opt_mb_fc == $WRITE_SINGLE_COIL) {
  $tx_hd_length  = 6;
  my $tx_bd_bit_value = ($opt_bit_value == 1) ? 0xFF : 0x00;
  my $tx_bd_padding   = 0;
  $tx_buffer = pack("nnnCCnCC", $tx_hd_tr_id, $tx_hd_pr_id,
                                $tx_hd_length, $tx_hd_unit_id,
                                $tx_bd_fc, $tx_bd_ad,
                                $tx_bd_bit_value, $tx_bd_padding);
## Trame d'écriture d'un mot
} elsif ($opt_mb_fc == $WRITE_SINGLE_REGISTER) {
  $tx_hd_length  = 6;
  my $tx_bd_word_value = $opt_word_value;
  $tx_buffer = pack("nnnCCnn", $tx_hd_tr_id, $tx_hd_pr_id,
                               $tx_hd_length, $tx_hd_unit_id,
                               $tx_bd_fc, $tx_bd_ad,
                               $tx_bd_word_value);
}
# Emission de la requête
send(SERVER, $tx_buffer, 0);
# Gestion du mode dump
dump_frame('Tx', $tx_buffer) if ($opt_dump_mode);
# Attente d'une réponse
if (!can_read('SERVER', $opt_timeout)) {
  close SERVER;
  print STDERR 'receive timeout'."\n";
  exit 1;
}
# Réception de l'entête
my ($rx_frame, $rx_buffer, $rx_body, $rx_hd_tr_id, $rx_hd_pr_id, $rx_hd_length, $rx_hd_unit_id,
    $rx_bd_fc, $rx_bd_bc, $rx_bd_data, @rx_disp_data);
recv(SERVER, $rx_buffer, 7, 0); $rx_frame = $rx_buffer;
# Décodage de l'entête
($rx_hd_tr_id, $rx_hd_pr_id, $rx_hd_length, $rx_hd_unit_id) = unpack "nnnC", $rx_buffer;
# Vérifie la cohérence de l'entête
if (!(($rx_hd_tr_id == $tx_hd_tr_id) && ($rx_hd_pr_id == 0) &&
      ($rx_hd_length < 256) && ($rx_hd_unit_id == $tx_hd_unit_id))) {
  close SERVER;
  dump_frame('Rx', $rx_frame) if ($opt_dump_mode);
  print STDERR 'error in receive frame'."\n";
  exit 1;
}
# Réception du corps du message
recv(SERVER, $rx_buffer, $rx_hd_length-1, 0);
$rx_frame .= $rx_buffer;
close SERVER;
# Gestion du mode dump
dump_frame('Rx', $rx_frame) if ($opt_dump_mode);
# Décodage du corps du message
($rx_bd_fc, $rx_body) = unpack "Ca*", $rx_buffer;
# *** Affichage du resultat ***
# Vérification du statut d'exception
if ($rx_bd_fc > 0x80) {
  # Affichage du code exception
  my $rx_except_code;
  ($rx_except_code) = unpack "C", $rx_body;
  print 'exception (code '.$rx_except_code.')'."\n";
} else {
  # Traitement du résultat de la demande selon le "code fonction"
  if (($opt_mb_fc == $READ_COILS) || ($opt_mb_fc == $READ_DISCRETE_INPUTS)) {
  ## Lecture de bit
    my $bit_str;
    ($rx_bd_bc, $bit_str) = unpack "Cb*", $rx_body;
    @rx_disp_data = split //, $bit_str;
    $#rx_disp_data = $opt_mb_nb - 1;
    disp_data(@rx_disp_data);
  } elsif (($opt_mb_fc == $READ_HOLDING_REGISTERS) ||
            ($opt_mb_fc == $READ_INPUT_REGISTERS)) {
  ## Lecture de mot
    my $rx_read_word_data;
    ($rx_bd_bc, $rx_read_word_data) = unpack "Ca*", $rx_body;
    # Décodage selon le mode d'affichage (avec ou sans IEEE)
    if ($opt_ieee) {
      # Lecture de flottant simple précision de 32 bits
      @rx_disp_data = unpack 'f*', pack 'L*', unpack 'N*', $rx_read_word_data;
      disp_data(@rx_disp_data);
    } else {
      # Lecture d'entier de 16 bits
      @rx_disp_data = unpack 'n*', $rx_read_word_data;
      disp_data(@rx_disp_data);
    }
  } elsif (($opt_mb_fc == $WRITE_SINGLE_COIL)) {
  ## Ecriture de bit
    my ($rx_bd_ad, $rx_bit_value);
    ($rx_bd_ad, $rx_bit_value) = unpack "nC", $rx_body;
    $rx_bit_value = ($rx_bit_value == 0xFF);
    if ($rx_bit_value == $opt_bit_value) {
      print 'bit write ok'."\n";
    } else {
      print 'bit write error'."\n";
    }
  } elsif (($opt_mb_fc == $WRITE_SINGLE_REGISTER)) {
  ## Ecriture de mot
    my ($rx_bd_ad, $rx_word_value);
    ($rx_bd_ad, $rx_word_value) = unpack "nn", $rx_body;
    if ($rx_word_value == $opt_word_value) {
      print 'word write ok'."\n";
    } else {
      print 'word write error'."\n";
    }
  }
}

# *** Sous-programmes divers ***
# Affichage d'une trame ModBus/TCP ("[header]body")
sub dump_frame {
  my ($frame_name, $frame) = @_;
  print $frame_name."\n";
  my @frame_bytes = unpack("C*", $frame);
  my $i = 0;
  print "[";
  foreach my $byte (@frame_bytes) {
     printf "%02X", $byte;
     print "]" if ($i++ == 6);
     print " ";
  }
  print "\n\n";
}

# Affichage des valeurs reçues
sub disp_data {
  # Affichage du résultat
  if ($opt_script_mode) {
    # Format csv pour utilisation dans un script
    foreach (@_) {
      if ($opt_ieee) {
        printf '%0.2f;', $_;
      } else {
        printf '%05d;', $_;
      }
    }
    print "\n";
  } else {
    # Format classique pour usage en ligne de commande
    print 'values:'."\n";
    my $nb = 0; my $base_addr = $opt_mb_ad;
    my $disp_format;
    $disp_format = '%3d (ad %05d): ';
    $disp_format = '%3d (ad 0x%04x): ' if ($opt_hex_ad);
    if ((!$opt_hex_value) and $opt_ieee)  {
      $disp_format .= '%0.6f';
    } elsif ($opt_hex_value and $opt_ieee) {
      $disp_format .= '0x%08x';
    } elsif ($opt_hex_value) {
      $disp_format .= '0x%04x';
    } else {
      $disp_format .= '%5d';
    }
    foreach (@_) {
      printf $disp_format."\n", ++$nb, $base_addr, $_;
      $base_addr++;
      $base_addr++ if ($opt_ieee);
    }
  }
}

# Attend $timeout secondes que la socket mette à disposition des données
sub can_read {
  my ($sock_handle, $timeout) = @_;
  my $hdl_select = "";
  vec($hdl_select, fileno($sock_handle), 1) = 1;
  return (select($hdl_select, undef, undef, $timeout) == 1);
}