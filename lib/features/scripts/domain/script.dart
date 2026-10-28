class GitHubConfig {
  const GitHubConfig({
    this.repository = '',
    this.branch = 'main',
    this.folder = 'scripts',
  });
  final String repository;
  final String branch;
  final String folder;
}

class ScriptFile {
  const ScriptFile({required this.name, required this.path});
  final String name;
  final String path;
}

class ScriptDocument {
  const ScriptDocument({required this.name, required this.source, this.domain});
  final String name;
  final String source;
  final String? domain;

  static const example = ScriptDocument(
    name: 'Example script',
    source:
        "const button = document.querySelector('button');\nif (!button) throw new Error('No button found');\nbutton.click();\nreturn 'Button clicked';",
  );
}
