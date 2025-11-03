use FindBin;
use lib "$FindBin::Bin/lib";
use Dancer2;

use Api::FederationApp;

# Return the Dancer2 PSGI app in a compatible way
return Api::FederationApp->psgi_app;
