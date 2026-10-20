#!/bin/bash

set -euo pipefail

# Wikimedia's CDN rejects Gerrit fetches from cloud IPs that send git's default User-Agent
export GIT_HTTP_USER_AGENT='ProfessionalWikiCIBot/1.0 (https://professional.wiki; tech@professional.wiki)'

# Submodules of Wikimedia repositories point at Gerrit and Phabricator. A Gerrit project "<namespace>/<name>"
# mirrors to GitHub "wikimedia/<namespace>-<name>". Git applies the longest matching rule, so the exact-URL rules
# win over the prefix rules.
MIRROR_RULES=(
	"https://gerrit.wikimedia.org/r/mediawiki/extensions/ https://github.com/wikimedia/mediawiki-extensions-"
	"https://gerrit.wikimedia.org/r/mediawiki/skins/ https://github.com/wikimedia/mediawiki-skins-"
	"https://gerrit.wikimedia.org/r/mediawiki/vendor https://github.com/wikimedia/mediawiki-vendor"
	"https://gerrit.wikimedia.org/r/VisualEditor/VisualEditor https://github.com/wikimedia/VisualEditor"
	"https://gerrit.wikimedia.org/r/wikibase/ https://github.com/wikimedia/wikibase-"
	"https://gerrit.wikimedia.org/r/data-values/ https://github.com/wikimedia/data-values-"
	"https://gerrit.wikimedia.org/r/design/ https://github.com/wikimedia/design-"
	"https://gerrit.wikimedia.org/r/wikibase/new-lexeme-special-page https://github.com/wmde/new-lexeme-special-page"
	"https://phabricator.wikimedia.org/source/wikibase-serialization.git https://github.com/wmde/WikibaseSerializationJavaScript.git"
	"https://phabricator.wikimedia.org/source/datavalues-javascript.git https://github.com/wmde/DataValuesJavaScript.git"
	"https://phabricator.wikimedia.org/source/wikibase-data-model.git https://github.com/wmde/WikibaseDataModelJavaScript.git"
)

GIT_CONFIG_COUNT=0
for rule in "${MIRROR_RULES[@]}"; do
	read -r upstream mirror <<<"$rule"
	export "GIT_CONFIG_KEY_$GIT_CONFIG_COUNT=url.$mirror.insteadOf"
	export "GIT_CONFIG_VALUE_$GIT_CONFIG_COUNT=$upstream"
	GIT_CONFIG_COUNT=$((GIT_CONFIG_COUNT + 1))
done
export GIT_CONFIG_COUNT

# Cloned rather than downloaded as a tarball: the tarball lacks phpunit.xml.template, which `composer phpunit:config` needs
git clone --depth 1 --branch "$MW_VERSION" https://github.com/wikimedia/mediawiki.git mediawiki
cd mediawiki

composer_includes="\"extensions/$EXTENSION/composer.json\""
for dependency in $DEPENDENCIES; do
	git clone --depth 1 --branch "$MW_VERSION" --recurse-submodules --shallow-submodules \
		"https://github.com/wikimedia/mediawiki-extensions-$dependency.git" "extensions/$dependency"
	composer_includes+=", \"extensions/$dependency/composer.json\""
done

cat >composer.local.json <<EOT
{
	"extra": {
		"merge-plugin": {
			"merge-dev": true,
			"include": [ $composer_includes ]
		}
	}
}
EOT

composer config --no-plugins allow-plugins.composer/installers true
composer update --no-interaction

php maintenance/install.php --dbtype sqlite --dbuser root --dbname mw --dbpath "$(pwd)" --pass AdminPassword WikiName AdminUser

cat >>LocalSettings.php <<'EOT'
error_reporting( E_ALL );
ini_set( 'display_errors', '1' );
$wgShowExceptionDetails = true;
$wgShowDBErrorBacktrace = true;
$wgDevelopmentWarnings = true;
EOT

printf '%s\n' "$SETTINGS" >>LocalSettings.php
printf "wfLoadExtension( '%s' );\n" "$EXTENSION" >>LocalSettings.php
