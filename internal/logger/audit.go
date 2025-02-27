// Copyright (c) 2015-2021 MinIO, Inc.
//
// This file is part of MinIO Object Storage stack
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

package logger

import (
	"context"
	"fmt"
	"net/http"
	"strconv"
	"time"

	internalAudit "github.com/minio/minio/internal/logger/message/audit"
	"github.com/minio/pkg/logger/message/audit"

	"github.com/klauspost/compress/gzhttp"
	"github.com/minio/madmin-go/v2"
	xhttp "github.com/minio/minio/internal/http"
)

const contextAuditKey = contextKeyType("audit-entry")

// SetAuditEntry sets Audit info in the context.
func SetAuditEntry(ctx context.Context, audit *audit.Entry) context.Context {
	if ctx == nil {
		LogIf(context.Background(), fmt.Errorf("context is nil"))
		return nil
	}
	return context.WithValue(ctx, contextAuditKey, audit)
}

// GetAuditEntry returns Audit entry if set.
func GetAuditEntry(ctx context.Context) *audit.Entry {
	if ctx != nil {
		r, ok := ctx.Value(contextAuditKey).(*audit.Entry)
		if ok {
			return r
		}
		r = &audit.Entry{
			Version:      internalAudit.Version,
			DeploymentID: xhttp.GlobalDeploymentID,
			Time:         time.Now().UTC(),
		}
		return r
	}
	return nil
}

// AuditLog - logs audit logs to all audit targets.
func AuditLog(ctx context.Context, w http.ResponseWriter, r *http.Request, reqClaims map[string]interface{}, filterKeys ...string) {
	auditTgts := AuditTargets()
	if len(auditTgts) == 0 {
		return
	}

	var entry audit.Entry
	if w != nil && r != nil {
		reqInfo := GetReqInfo(ctx)
		if reqInfo == nil {
			return
		}
		reqInfo.RLock()
		defer reqInfo.RUnlock()

		entry = internalAudit.ToEntry(w, r, reqClaims, xhttp.GlobalDeploymentID)
		// indicates all requests for this API call are inbound
		entry.Trigger = "incoming"

		for _, filterKey := range filterKeys {
			delete(entry.ReqClaims, filterKey)
			delete(entry.ReqQuery, filterKey)
			delete(entry.ReqHeader, filterKey)
			delete(entry.RespHeader, filterKey)
		}

		var (
			statusCode      int
			timeToResponse  time.Duration
			timeToFirstByte time.Duration
			outputBytes     int64 = -1 // -1: unknown output bytes
			headerBytes     int64
		)

		var st *xhttp.ResponseRecorder
		switch v := w.(type) {
		case *xhttp.ResponseRecorder:
			st = v
		case *gzhttp.GzipResponseWriter:
			// the writer may be obscured by gzip response writer
			if rw, ok := v.ResponseWriter.(*xhttp.ResponseRecorder); ok {
				st = rw
			}
		case *gzhttp.NoGzipResponseWriter:
			// the writer may be obscured by no-gzip response writer
			if rw, ok := v.ResponseWriter.(*xhttp.ResponseRecorder); ok {
				st = rw
			}
		}
		if st != nil {
			statusCode = st.StatusCode
			timeToResponse = time.Now().UTC().Sub(st.StartTime)
			timeToFirstByte = st.TimeToFirstByte
			outputBytes = int64(st.Size())
			headerBytes = int64(st.HeaderSize())
		}

		entry.AccessKey = reqInfo.Cred.AccessKey
		entry.ParentUser = reqInfo.Cred.ParentUser

		entry.API.Name = reqInfo.API
		entry.API.Bucket = reqInfo.BucketName
		entry.API.Object = reqInfo.ObjectName
		entry.API.Objects = make([]audit.ObjectVersion, 0, len(reqInfo.Objects))
		for _, ov := range reqInfo.Objects {
			entry.API.Objects = append(entry.API.Objects, audit.ObjectVersion{
				ObjectName: ov.ObjectName,
				VersionID:  ov.VersionID,
			})
		}
		entry.API.Status = http.StatusText(statusCode)
		entry.API.StatusCode = statusCode
		entry.API.InputBytes = r.ContentLength
		entry.API.OutputBytes = outputBytes
		entry.API.HeaderBytes = headerBytes
		entry.API.TimeToResponse = strconv.FormatInt(timeToResponse.Nanoseconds(), 10) + "ns"
		entry.Tags = reqInfo.GetTagsMap()
		// ttfb will be recorded only for GET requests, Ignore such cases where ttfb will be empty.
		if timeToFirstByte != 0 {
			entry.API.TimeToFirstByte = strconv.FormatInt(timeToFirstByte.Nanoseconds(), 10) + "ns"
		}
	} else {
		auditEntry := GetAuditEntry(ctx)
		if auditEntry != nil {
			entry = *auditEntry
		}
	}

	// Send audit logs only to http targets.
	for _, t := range auditTgts {
		if err := t.Send(entry); err != nil {
			LogAlwaysIf(context.Background(), fmt.Errorf("event(%v) was not sent to Audit target (%v): %v", entry, t, err), madmin.LogKindAll)
		}
	}
}
