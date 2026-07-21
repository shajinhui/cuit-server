package migrations

import (
	"context"
	"database/sql"
	"embed"
	"fmt"
	"strings"
)

//go:embed *.sql
var migrationFiles embed.FS

func Apply(ctx context.Context, db *sql.DB) error {
	entries, err := migrationFiles.ReadDir(".")
	if err != nil {
		return fmt.Errorf("migrations: list files: %w", err)
	}
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".sql") {
			continue
		}
		statement, err := migrationFiles.ReadFile(entry.Name())
		if err != nil {
			return fmt.Errorf("migrations: read %s: %w", entry.Name(), err)
		}
		if _, err := db.ExecContext(ctx, string(statement)); err != nil {
			return fmt.Errorf("migrations: apply %s: %w", entry.Name(), err)
		}
	}
	return nil
}
