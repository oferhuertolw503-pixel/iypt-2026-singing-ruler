// Copyright 2026 The MathWorks, Inc.

package telemetry

import (
	"context"

	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/telemetry/otel"
	"github.com/matlab/matlab-mcp-core-server/internal/adaptors/telemetry/otel/instruments"
	"github.com/matlab/matlab-mcp-core-server/internal/entities"
	"github.com/matlab/matlab-mcp-core-server/internal/messages"
)

type Directory interface {
	ID() string
}

type Config interface {
	Version() string
	WatchdogMode() bool
	SpecifiedParameters() []string
	AsPIISafeJSONString() string
}

type otelTelemetry struct {
	logger            entities.Logger
	meter             otel.Meter
	instrumentFactory InstrumentFactory

	config            Config
	directory         Directory
	osLayer           OSLayer
	osVersionProvider OSVersionProvider
	definition        Definition

	// Instruments
	serverStartCounter instruments.Int64Counter
}

func newOTELTelemetry(
	logger entities.Logger,
	meter otel.Meter,
	instrumentFactory InstrumentFactory,
	cfg Config,
	dir Directory,
	osLayer OSLayer,
	osVersionProvider OSVersionProvider,
	definition Definition,
) (*otelTelemetry, messages.Error) {
	telemetry := &otelTelemetry{
		logger:            logger,
		meter:             meter,
		instrumentFactory: instrumentFactory,
		config:            cfg,
		directory:         dir,
		osLayer:           osLayer,
		osVersionProvider: osVersionProvider,
		definition:        definition,
	}

	err := telemetry.createInstruments(logger)
	if err != nil {
		return nil, err
	}

	return telemetry, nil
}

func (t *otelTelemetry) RecordServerStart(ctx context.Context) {
	if t.config.WatchdogMode() {
		t.logger.Debug("Skipping server start metric in watchdog mode")
		return
	}

	t.logger.Debug("Recording server start metric")
	attributes := NewAttributes()

	if err := attributes.AddString("server.instance_id", t.directory.ID()); err != nil {
		t.logger.WithError(err).Debug("Failed to add server.instance_id attribute")
	}
	if err := attributes.AddString("server.name", t.definition.Name()); err != nil {
		t.logger.WithError(err).Debug("Failed to add server.name attribute")
	}
	if err := attributes.AddString("server.version", t.config.Version()); err != nil {
		t.logger.WithError(err).Debug("Failed to add server.version attribute")
	}
	if err := attributes.AddStringSlice("server.specified_parameters", t.config.SpecifiedParameters()); err != nil {
		t.logger.WithError(err).Debug("Failed to add server.specified_parameters attribute")
	}
	if err := attributes.AddString("server.config_details", t.config.AsPIISafeJSONString()); err != nil {
		t.logger.WithError(err).Debug("Failed to add server.config_details attribute")
	}
	if err := attributes.AddString("server.os", t.osLayer.GOOS()); err != nil {
		t.logger.WithError(err).Debug("Failed to add server.os attribute")
	}
	osVersion, err := t.osVersionProvider.Version()
	if err != nil {
		t.logger.WithError(err).Debug("Failed to get OS version")
		osVersion = ""
	}
	if err := attributes.AddString("server.os_version", osVersion); err != nil {
		t.logger.WithError(err).Debug("Failed to add server.os_version attribute")
	}

	t.serverStartCounter.Add(ctx, 1, attributes.AsOTEL())
}

func (t *otelTelemetry) createInstruments(logger entities.Logger) messages.Error {
	logger.Debug("Creating telemetry instruments")
	defer logger.Debug("Done creating telemetry instruments")

	serverStartCounter, err := t.instrumentFactory.NewInt64Counter(t.meter, "server.starts", "Number of times the server has started", "{start}")
	if err != nil {
		logger.WithError(err).Error("Failed to create server start counter")
		return messages.New_StartupErrors_TelemetryInitializationFailed_Error()
	}
	t.serverStartCounter = serverStartCounter

	return nil
}
