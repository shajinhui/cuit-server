package feedback

import (
	"context"
	"database/sql"
	"fmt"
	"time"
)

type Repository struct {
	db  *sql.DB
	now func() time.Time
}

func NewRepository(db *sql.DB) *Repository {
	return &Repository{db: db, now: time.Now}
}

func (r *Repository) Create(
	ctx context.Context,
	userID int64,
	submission Submission,
) (Record, error) {
	createdAt := r.now().UTC()
	result, err := r.db.ExecContext(ctx, `
INSERT INTO feedback (
    user_id, feedback_type, platform, content, user_agent, created_at
)
VALUES (?, ?, ?, ?, ?, ?)`,
		userID,
		submission.Type,
		submission.Platform,
		submission.Content,
		submission.UserAgent,
		createdAt,
	)
	if err != nil {
		return Record{}, fmt.Errorf("feedback: create: %w", err)
	}
	id, err := result.LastInsertId()
	if err != nil {
		return Record{}, fmt.Errorf("feedback: read created ID: %w", err)
	}
	return Record{
		ID:        id,
		UserID:    userID,
		Type:      submission.Type,
		Platform:  submission.Platform,
		Content:   submission.Content,
		UserAgent: submission.UserAgent,
		CreatedAt: createdAt,
	}, nil
}

func (r *Repository) ListRecent(ctx context.Context, limit int) ([]Record, error) {
	rows, err := r.db.QueryContext(ctx, `
SELECT id, user_id, feedback_type, platform, content, user_agent, created_at
FROM feedback
ORDER BY created_at DESC, id DESC
LIMIT ?`, limit)
	if err != nil {
		return nil, fmt.Errorf("feedback: list recent: %w", err)
	}
	defer rows.Close()

	records := make([]Record, 0, limit)
	for rows.Next() {
		var record Record
		var rawCreatedAt string
		if err := rows.Scan(
			&record.ID,
			&record.UserID,
			&record.Type,
			&record.Platform,
			&record.Content,
			&record.UserAgent,
			&rawCreatedAt,
		); err != nil {
			return nil, fmt.Errorf("feedback: scan recent: %w", err)
		}
		record.CreatedAt, err = parseStoredTime(rawCreatedAt)
		if err != nil {
			return nil, fmt.Errorf("feedback: parse creation time: %w", err)
		}
		records = append(records, record)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("feedback: iterate recent: %w", err)
	}
	return records, nil
}

func parseStoredTime(value string) (time.Time, error) {
	layouts := []struct {
		layout   string
		location *time.Location
	}{
		{time.RFC3339Nano, nil},
		{"2006-01-02 15:04:05.999999999 -0700 MST", nil},
		{"2006-01-02 15:04:05 -0700 MST", nil},
		{"2006-01-02 15:04:05.999999999", time.UTC},
		{"2006-01-02 15:04:05", time.UTC},
	}
	for _, candidate := range layouts {
		var parsed time.Time
		var err error
		if candidate.location == nil {
			parsed, err = time.Parse(candidate.layout, value)
		} else {
			parsed, err = time.ParseInLocation(candidate.layout, value, candidate.location)
		}
		if err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, fmt.Errorf("unsupported timestamp %q", value)
}
