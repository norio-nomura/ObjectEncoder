workflow "New workflow" {
  on = "push"
  resolves = ["GitHub Action for SwiftLint"]
}

action "GitHub Action for SwiftLint" {
  uses = "norio-nomura/action-swiftlint@1.0.0"
  secrets = ["GITHUB_TOKEN"]
}
