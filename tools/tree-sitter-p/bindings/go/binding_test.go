package tree_sitter_p_test

import (
	"testing"

	tree_sitter "github.com/tree-sitter/go-tree-sitter"
	tree_sitter_p "github.com/tomcat-42/p/bindings/go"
)

func TestCanLoadGrammar(t *testing.T) {
	language := tree_sitter.NewLanguage(tree_sitter_p.Language())
	if language == nil {
		t.Errorf("Error loading P grammar")
	}
}
