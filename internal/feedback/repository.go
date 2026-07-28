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
