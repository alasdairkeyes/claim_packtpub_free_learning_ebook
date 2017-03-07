#!/usr/bin/perl


## Define PacktPub account email/password
## ONLY EDIT THESE TWO LINES
    my $packtpub_email      = '';
    my $packtpub_password   = '';
## DON'T EDIT ANYTHING BELOW HERE



## Include Modules and version
    use strict;
    use warnings;
    use LWP::UserAgent;
    use HTTP::Cookies;
    use Data::Dumper;
    use Encode;
    my $VERSION = '0.4';


## Check we have details required
    $packtpub_email     || die "Please add email to script $0";
    $packtpub_password  || die "Please add password to script $0";


## Add in Debug
    use constant DEBUG => (grep { $_ eq '-v' } @ARGV)
        ? 1
        : 0;

    sub debug {
        return unless DEBUG;
        print "DEBUG: " . join(' ', @_) . "\n";
        return 1;
    }


## Define Domain/URLs required
    my $packt_pub_domain    ='https://www.packtpub.com';
    my $free_learning_uri   = join('', $packt_pub_domain, '/packt/offers/free-learning');
    my $my_ebooks_uri       = join('', $packt_pub_domain, '/account/my-ebooks');


## Create UserAgent object with a cookie jar
    my $ua = LWP::UserAgent->new(
        timeout     => 10
    ) || die "Failed to create UserAgent";

    $ua->cookie_jar( HTTP::Cookies->new() );

    debug("Created LWP::UserAgent object");


## Get Free learning page
    my $free_learning_response = $ua->get($free_learning_uri);
    my $free_learning_content = $free_learning_response->decoded_content;
    die "Failed to get '$free_learning_uri': " . $free_learning_response->status_line
        unless $free_learning_response->is_success;

    debug("Fetched '$free_learning_uri'");


## Packt don't always run the deal, detect when this is the case... inform and quit
    my @non_running_strings = (
        'Access over 4,000 eBooks &amp; video courses. Free for 10 days'
	);
    foreach my $non_running_string (@non_running_strings) {
        if (index($free_learning_content, $non_running_string) >= 0) {
            print "It appears that Packt aren't running their free books at the moment.\n";
			print "Check $free_learning_uri for information on when it will return";
            exit;
        }
    }


## Get login form 'form_build_id'
    my @login_form_build_ids = ( $free_learning_content =~ m{name="form_build_id"\s+id="(form-[a-z0-9]{32})"}gms );
    my $login_form_build_id = shift (@login_form_build_ids)
            || die "Failed to get form_build_id for login";

    debug("Got login_form_build_id '$login_form_build_id'");


## Get Book title data
    my @h2 = ( $free_learning_content =~ m{<h2>.*?</h2>}gms );
    my $title = shift (@h2);
    $title =~ s{^<h2>\s*}{};
    $title =~ s{\s*</h2>$}{};
    $title || die "Failed to get title";


## Get Book purchase link
    my @p_links = ( $free_learning_content =~ m#<a href="(/freelearning-claim/\d+/\d+)"# );
    my $p_link = shift(@p_links)
        || die "Failed to get purchase link";
    $p_link = join('', $packt_pub_domain, $p_link);

    debug("Got title of '$title'");


## Login to Packt pub, 200 response on failure, 302 on success
    my $login_response = $ua->post($free_learning_uri, {
        email           => $packtpub_email,
        password        => $packtpub_password,
        op              => 'Login',
        form_build_id   => $login_form_build_id,
        form_id         => 'packt_user_login_form',
    });

    debug("Login Response Dump:", Dumper($login_response));

    my $required_login_status = 302;
    die "Failed to get $required_login_status response from login"
        unless ($login_response->code eq $required_login_status);

    debug("Logged in and obtained $required_login_status response");


## Call the URI to order the free book
    my $get_book_response = $ua->get($p_link);


## 302 redirect to $my_ebooks_uri on success, else die
    my $required_purchase_status = 302;
    my @known_redirect_urls = (
        $packt_pub_domain,
        $my_ebooks_uri
    );
    die "Failed to get $required_purchase_status redirect to a known URL after purchase"
        unless ($get_book_response->previous->code eq $required_purchase_status &&
            grep { $get_book_response->previous->headers->header('location') eq $_ } @known_redirect_urls);

    debug("Get Book Response Dump", Dumper($get_book_response));


## Alert that the new book has been obtained
    print "Purchased Today's free book '" . encode('utf-8', $title) . "'\nGet it at $my_ebooks_uri\n";
