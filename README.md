# setup-mediawiki

GitHub Action that installs MediaWiki for an extension's CI, with the calling repository as the extension.

## Usage

```yaml
steps:
  - uses: shivammathur/setup-php@v2
    with:
      php-version: '8.3'
      extensions: mbstring, intl
      tools: composer

  - uses: ProfessionalWiki/setup-mediawiki@v1
    with:
      mw-version: REL1_43
      extension: WikibaseRDF
      dependencies: Wikibase
      settings: |
        wfLoadExtension( 'WikibaseRepository', __DIR__ . '/extensions/Wikibase/extension-repo.json' );
        require_once __DIR__ . '/extensions/Wikibase/repo/ExampleSettings.php';

  - run: php maintenance/update.php --quick
    working-directory: mediawiki
```

The action needs PHP and Composer on the runner.

## Inputs

| Input          | Required | Description                                                                        |
|----------------|----------|------------------------------------------------------------------------------------|
| `mw-version`   | yes      | MediaWiki branch, such as `REL1_43` or `master`. Dependencies use the same branch. |
| `extension`    | yes      | Name of the extension. The calling repository is checked out as it and loaded.    |
| `dependencies` | no       | Wikimedia extensions to clone, separated by whitespace. Load them via `settings`.  |
| `settings`     | no       | PHP appended to `LocalSettings.php` before the extension is loaded.                |

## Result

* MediaWiki in `mediawiki/` in the workspace, installed with SQLite. The admin user is `AdminUser`, password
  `AdminPassword`.
* The calling repository at `mediawiki/extensions/<extension>`, loaded after `settings`.
* The dependencies in `mediawiki/extensions/`, fetched from Wikimedia's GitHub mirrors.
* Composer dependencies of MediaWiki, the extension and its dependencies, including development dependencies.
* Composer no longer blocks packages with security advisories, for the rest of the job.

The action does not run `update.php`. Run it when the extension or its dependencies add database tables.

The installation, before the extension is checked out, is cached. The cache refreshes when MediaWiki, a dependency,
an input, or the PHP minor version changes.
