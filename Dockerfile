FROM perl:5.20
COPY . /data/pipsqueek/
WORKDIR /data/pipsqueek
RUN cpanm Carp \
    && cpanm DateTime::Locale \
    && cpanm IPC::System::Simple \
    && cpanm Class::Accessor::Fast \
    && cpanm XML::LibXML::Element \
    && cpanm DateTime::Format::Mail  \
    && cpanm DateTime::Format::W3CDTF \
    && cpanm DBD::SQLite \
    && cpanm Data::Dumper \
    && cpanm Date::Format \
    && cpanm Date::Language \
    && cpanm Date::Parse \
    && cpanm DBI \
    && cpanm Exporter \
    && cpanm File::Find \
    && cpanm File::Path \
    && cpanm File::Spec::Functions \
    && cpanm Filter::Template \
    && cpanm FindBin \
    && cpanm integer \
    && cpanm IP::Country::MaxMind \
    && cpanm JSON \
    && cpanm Lingua::Ispell \
    && cpanm LWP::UserAgent \
    && cpanm overload \
    && cpanm Parse::RecDescent \
    && cpanm Physics::Unit \
    && cpanm XML::LibXML::Element \
    && cpanm POE \
    && cpanm POE::Component::IRC \
    && cpanm POSIX \
    && cpanm Time::Local \
    && cpanm Time::Zone \
    && cpanm URI::Escape \
    && cpanm URI::Find::Schemeless \
    && cpanm URI::URL \
    && cpanm utf8 \
    && cpanm Geo::IP::PurePerl \
    && cpanm Schedule::Cron::Events \
    && cpanm WWW::WolframAlpha \
    && cpanm XML::RSS 
CMD [ "perl", "./bin/pipsqueek.pl", "-d /data/pipsqueek/client"]

