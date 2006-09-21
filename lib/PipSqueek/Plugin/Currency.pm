package PipSqueek::Plugin::Currency;
use base qw(PipSqueek::Plugin);

use LWP::UserAgent;

sub plugin_initialize
{
	my $self = shift;

	$self->plugin_handlers({
		'multi_money'    => 'multi_money',
		'multi_exchange' => 'multi_money',
		'multi_currency' => 'multi_currency',
	});

	my $schema = [
		[ 'id',		'INTEGER PRIMARY KEY' ],
		[ 'country',	'VARCHAR NOT NULL' ],
		[ 'code',	'VARCHAR NOT NULL' ],
		[ 'billname',	'VARCHAR NOT NULL' ],
	];

	if( $self->dbi()->install_schema( 'currency', $schema ) )
	{
		my $sql = 
		'INSERT INTO currency (country,code,billname) VALUES(?,?,?)';

		my $sth = $self->dbi()->dbh()->prepare( $sql );

		print STDERR "Creating currency database... (this could take a bit): ";
		foreach my $line (<DATA>)
		{
			chomp($line);
			my (@values) = split(/\t/,$line);
			next unless @values == 3;
			$sth->execute( @values );
		}
		print STDERR "[OK]\n";
	}
}


sub multi_money
{
	my ($self,$message) = @_;

	$message->command_input() =~ m/^
		([\$[+-]?[\d\.]+|_)?\s*
		(?:from\s+)?
		([[:alpha:]]{3})\s+
		(?:to\s+)?
		([[:alpha:]]{3})
		/ix;

	my ($amount,$from,$to) = ($1||1,$2,$3);

	my $session_heap = $self->client()->get_heap();

	# users can use '_' to insert values from previous money or math calls
	if ( $amount eq '_' )
	{
		$amount = $session_heap->{'last_math_result'} || 1;
	}

	unless( defined($amount) && $from && $to )
	{
		$self->respond( $message, "See !help exchange" );
		return;
	}

	my $url  = 'http://www.xe.com/ucc/convert.cgi' .
		   "?Amount=$amount&From=$from&To=$to" .
		   '&Header=PipSqueek&Footer=PipSqueek';

	my $browser  = LWP::UserAgent->new( 'agent' => 'Mozilla/5.0' );
	my $response = $browser->get( $url ); 

	unless( $response->is_success()	&&
		$response->content_type() eq 'text/html' )
	{
		$self->respond( $message, 
			"HTTP Error or invalid content type" );
		return;
	}

	my $results = $response->content();

	# get the exchange rate and do the math ourselves
	my ($factor) = $results =~ m/1 $from = ([\d\.\,]+) $to/i;
	$factor =~ s/,//g;

	my $a = $amount;
	my $b = $amount * $factor;

	# store the conversion result on the heap as '_' for future calls
	$session_heap->{'last_math_result'} = $b;

	return $self->respond( $message, "$a $from = $b $to" );
}


sub multi_currency
{
	my ($self,$message) = @_;

	my $country = $message->command_input();

	if( length($country) < 4 || !$country )
	{
		$self->respond( $message, "See !help currency" );
		return;
	}

	my @matches = $self->dbi()->select_record( 'currency', {
			'country' => [ 'LIKE', "\%$country\%" ] 
			} );

	if( @matches ) 
	{
		my @m = map { "$_->[1] ($_->[2])" } @matches;
		my $s = @m == 1 ? '' : 'es';
		local $"=', ';
		return $self->respond( $message, "Found match$s: @m" );
	}

	return $self->respond( $message, "Country code not found" );
}	


1;


__DATA__
Afghanistan	AFA	Afghani
Albania	ALL	Lek
Algeria	DZD	Dinar
America (United States)	USD	Dollar
American Samoa	USD	United States Dollar
Andorra	EUR	Euro
Angola	AOA	Kwanza
Anguilla	XCD	East Caribbean Dollar
Antigua and Barbuda	XCD	East Caribbean Dollar
Argentina	ARS	Peso
Armenia	AMD	Dram
Aruba	AWG	Guilder
Ashmore and Cartier Islands	AUD	Australia Dollar
Australia	AUD	Dollar
Austria	EUR	Euro
Austria	ATS	Schilling [obsolete]
Azerbaijan	AZM	Manat
Azores	EUR	Euro
Bahamas	BSD	Dollar
Bahrain	BHD	Dinar
Bajan (Barbados)	BBD	Dollar
Balearic Islands	EUR	Euro
Bangladesh	BDT	Taka
Barbados	BBD	Dollar
Belarus	BYR	Ruble
Belgium	EUR	Euro
Belgium	BEF	Franc [obsolete]
Belize	BZD	Dollar
Benin	XOF	CFA Franc BCEAO
Bermuda	BMD	Dollar
Bhutan	INR	India Rupee
Bhutan	BTN	Ngultrum
Bolivia	BOB	Boliviano
Bonaire	ANG	Netherlands Antilles Guilder
Bosnia and Herzegovina	BAM	Convertible Marka
Botswana	BWP	Pula
Brazil	BRL	Real
Britain (United Kingdom)	GBP	Pound
British Indian Ocean Territory	GBP	United Kingdom Pound
British Indian Ocean Territory	USD	United States Dollar
British Virgin Islands	USD	United States Dollar
Brunei	BND	Dollar
Brunei	SGD	Singapore Dollar
Bulgaria	BGL	Lev
Burkina Faso	XOF	CFA Franc BCEAO
Burma (Myanmar)	MMK	Kyat
Burundi	BIF	Franc
Cambodia	KHR	Riel
Cameroon	XAF	CFA Franc BEAC
Canada	CAD	Dollar
Canary Islands	EUR	Euro
Cape Verde	CVE	Escudo
Cayman Islands	KYD	Dollar
Central African Republic	XAF	CFA Franc BEAC
Chad	XAF	CFA Franc BEAC
Chile	CLP	Peso
China	CNY	Yuan Renminbi
Christmas Island	AUD	Australia Dollar
Cocos (Keeling Islands	AUD	Australia Dollar
Colombia	COP	Peso
Comoros	KMF	Franc
Congo/Brazzaville	XAF	CFA Franc BEAC
Congo/Kinshasa	CDF	Franc
Cook Islands	NZD	New Zealand Dollar
Coral Sea Islands	AUD	Australia Dollar
Costa Rica	CRC	Colon
Côte d'Ivoire	XOF	CFA Franc BCEAO
Croatia	HRK	Kuna
Cuba	CUP	Peso
Curaço	ANG	Netherlands Antilles Guilder
Cyprus	CYP	Pound
Czech Republic	CZK	Koruna
Denmark	DKK	Krone
Djibouti	DJF	Franc
Dominica	XCD	East Caribbean Dollar
Dominican Republic	DOP	Peso
Dutch (Netherlands)	EUR	Euro
Dutch (Netherlands)	NLG	Guilder [obsolete]
East Timor	USD	United States Dollar
Ecuador	USD	United States Dollar
Egypt	EGP	Pound
El Salvador	SVC	Colon
England (United Kingdom)	GBP	Pound
Equatorial Guinea	XAF	CFA Franc BEAC
Eritrea	ERN	Nakfa
Estonia	EEK	Kroon
Ethiopia	ETB	Birr
Europe	EUR	Euro
Europa Island	EUR	Euro
Falkland Islands	FKP	Pound
Faroe Islands	DKK	Denmark Krone
Fiji	FJD	Dollar
Finland	EUR	Euro
Finland	FIM	Markka [obsolete]
France	EUR	Euro
France	FRF	Franc [obsolete]
French Guiana	EUR	Euro
French Polynesia	XPF	Comptoirs Français du Pacifique Franc
French Polynesia	EUR	Euro
French Southern and Antarctic Lands	EUR	Euro
Gabon	XAF	CFA Franc BEAC
Gambia	GMD	Dalasi
Gaza Strip	ILS	Israel New Shekel
Georgia	GEL	Lari
Germany	DEM	Deutsche Mark [obsolete]
Germany	EUR	Euro
Ghana	GHC	Cedi
Gibraltar	GIP	Pound
Gold	XAU	Gold Ounce
Great Britain (United Kingdom)	GBP	Pound
Greece	EUR	Euro
Greece	GRD	Drachma [obsolete]
Greenland	DKK	Denmark Krone
Grenada	XCD	East Caribbean Dollar
Guadeloupe	EUR	Euro
Guam	USD	United States Dollar
Guatemala	GTQ	Quetzal
Guernsey	GGP	Pound
Guinea	GNF	Franc
Guinea-Bissau	XOF	CFA Franc BCEAO
Guyana	GYD	Dollar
Haiti	HTG	Gourde
Holland (Netherlands)	EUR	Euro
Holland (Netherlands)	NLG	Guilder [obsolete]
Holy See (Vatican City)	EUR	Euro
Holy See (Vatican City)	VAL	Lira [obsolete]
Honduras	HNL	Lempira
Hong Kong	HKD	Dollar
Hungary	HUF	Forint
Iceland	ISK	Krona
India	INR	Rupee
Indonesia	IDR	Rupiah
Iran	IRR	Rial
Iraq	IQD	Dinar
Ireland	EUR	Euro
Ireland	IEP	Pound [obsolete]
Islas Malvinas (Falkland Islands)	FKP	Pound
Isle of Man	IMP	Pound
Israel	ILS	New Shekel
Italy	EUR	Euro
Italy	ITL	Lira [obsolete]
Ivory Coast (Côte d'Ivoire)	XOF	CFA Franc BCEAO
Jamaica	JMD	Dollar
Japan	JPY	Yen
Jersey	JEP	Pound
Johnson	USD	United States Dollar
Jordan	JOD	Dinar
Juan de Nova	EUR	Euro
Kazakhstan	KZT	Tenge
Kenya	KES	Shilling
Kiribati	AUD	Australia Dollar
Kuwait	KWD	Dinar
Kyrgyzstan	KGS	Som
Laos	LAK	Kip
Latvia	LVL	Lat
Lebanon	LBP	Pound
Lesotho	LSL	Loti
Liberia	LRD	Dollar
Libya	LYD	Dinar
Liechtenstein	CHF	Switzerland Franc
Lithuania	LTL	Litas
Luxembourg	EUR	Euro
Luxembourg	LUF	Franc [obsolete]
Macau	MOP	Pataca
Macedonia	MKD	Denar
Madagascar	MGF	Franc
Madeira Islands	EUR	Euro
Malawi	MWK	Kwacha
Malaysia	MYR	Ringgit
Maldives	MVR	Rufiyaa
Mali	XOF	CFA Franc BCEAO
Malta	MTL	Lira
Malvinas (Falkland Islands)	FKP	Pound
Marshall Islands	USD	United States Dollar
Martinique	EUR	Euro
Mauritania	MRO	Ouguiya
Mauritius	MUR	Rupee
Mayotte	EUR	Euro
Mexico	MXN	Peso
Micronesia	USD	United States Dollar
Midway Islands	USD	United States Dollar
Moldova	MDL	Leu
Monaco	EUR	Euro
Mongolia	MNT	Tughrik
Montserrat	XCD	East Caribbean Dollar
Morocco	MAD	Dirham
Mozambique	MZM	Metical
Myanmar (Burma)	MMK	Kyat
Namibia	NAD	Dollar
Nauru	AUD	Australia Dollar
Navassa	HTG	Haiti Gourde
Navassa	USD	United States Dollar
Nepal	CNY	China Yuan Renminbi
Nepal	NPR	Rupee
Netherlands Antilles	ANG	Guilder
Netherlands	EUR	Euro
Netherlands	NLG	Guilder [obsolete]
New Caledonia	XPF	Comptoirs Français du Pacifique Franc
New Zealand	NZD	Dollar
Nicaragua	NIO	Gold Cordoba
Niger	XOF	CFA Franc BCEAO
Nigeria	NGN	Naira
Niue	NZD	New Zealand Dollar
Norfolk Island	AUD	Australia Dollar
North Korea	KPW	Won
Northern Mariana Islands	USD	United States Dollar
Norway	NOK	Krone
Oman	OMR	Rial
Pakistan	PKR	Rupee
Palau	USD	United States Dollar
Palladium	XPD	Palladium Ounce
Panama	PAB	Balboa
Panama	USD	United States Dollar
Papua New Guinea	PGK	Kina
Paracel Islands	CNY	China Yuan Renminbi
Paracel Islands	VND	Vietnam Dong
Paraguay	PYG	Guarani
Peru	PEN	Nuevo Sol
Philippines	PHP	Peso
Pitcairn	NZD	New Zealand Dollar
Platinum	XPT	Platinum Ounce
Poland	PLN	Zloty
Portugal	EUR	Euro
Portugal	PTE	Escudo [obsolete]
Puerto Rico	USD	United States Dollar
Qatar	QAR	Riyal
Reunion	EUR	Euro
Romania	ROL	Leu
Russia	RUR	Ruble
Rwanda	RWF	Franc
Saba	ANG	Netherlands Antilles Guilder
Saint Helena	SHP	Pound
Saint Kitts and Nevis	XCD	East Caribbean Dollar
Saint Lucia	XCD	East Caribbean Dollar
Saint Pierre and Miquelon	EUR	Euro
Saint Vincent and The Grenadines	XCD	East Caribbean Dollar
Saint-Martin	EUR	Euro
Samoa	WST	Tala
San Marino	EUR	Euro
São Tome and Principe	STD	Dobra
Saudi Arabia	SAR	Riyal
Scotland (United Kingdom)	GBP	Pound
Seborga	SPL	Luigino
Senegal	XOF	CFA Franc BCEAO
Seychelles	SCR	Rupee
Sierra Leone	SLL	Leone
Silver	XAG	Silver Ounce
Singapore	SGD	Dollar
Sint Eustatius	ANG	Netherlands Antilles Guilder
Sint Maarten	ANG	Netherlands Antilles Guilder
Slovakia	SKK	Koruna
Slovenia	SIT	Tolar
Solomon Islands	SBD	Dollar
Somalia	SOS	Shilling
South Africa	ZAR	Rand
South Georgia	GBP	United Kingdom Pound
South Korea	KRW	Won
South Sandwich Islands	GBP	United Kingdom Pound
Spain	EUR	Euro
Spain	ESP	Peseta [obsolete]
Sri Lanka	LKR	Rupee
Sudan	SDD	Dinar
Suriname	SRG	Guilder
Svalbard and Jan Mayen	NOK	Norway Krone
Swaziland	SZL	Lilangeni
Swaziland	ZAR	South Africa Rand
Sweden	SEK	Krona
Switzerland	CHF	Franc
Syria	SYP	Pound
Taiwan	TWD	New Dollar
Tajikistan	TJS	Somoni
Tajikistan	RUR	Russia Ruble
Tanzania	TZS	Shilling
Thailand	THB	Baht
Togo	XOF	CFA Franc BCEAO
Tokelau	NZD	New Zealand Dollar
Tonga	TOP	Pa'anga
Transnistria	MDL	Moldova Leu
Trinidad and Tobago	TTD	Dollar
Tunisia	TND	Dinar
Turkey	TRL	Lira
Turkmenistan	TMM	Manat
Turks and Caicos Islands	USD	United States Dollar
Tuvalu	AUD	Australia Dollar
Tuvalu	TVD	Dollar
Uganda	UGX	Shilling
Ukraine	UAH	Hryvna
United Arab Emirates	AED	Dirham
United Kingdom	GBP	Pound
United States	USD	Dollar
Uruguay	UYU	Peso
Uzbekistan	UZS	Som
Vanuatu	VUV	Vatu
Vatican City	EUR	Euro
Vatican City	VAL	Lira [obsolete]
Venezuela	VEB	Bolivar
Vietnam	VND	Dong
Virgin Islands	USD	United States Dollar
Wake Island	USD	United States Dollar
West Bank	ILS	Israel New Shekel
West Bank	JOD	Jordan Dinar
Western Sahara	MAD	Morocco Dirham
Western Samoa (Samoa)	WST	Tala
Yemen	YER	Rial
Yugoslavia	YUM	New Dinar
Yugoslavia	EUR	Euro
Zambia	ZMK	Kwacha
Zimbabwe	ZWD	Dollar
__END__
