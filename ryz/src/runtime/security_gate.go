package main

import (
	"fmt"
	"sync"
)

// SecurityGate implements memory-gating for RYZ plugins
// Reference: Arxiv 2604.24579 (Prop 1: TraceToChain Reliability)
// Logic: Enforces deterministic memory boundaries for Lua/Bun/Go/Rust plugins

type PluginType string

const (
	Lua  PluginType = "lua"
	Bun  PluginType = "bun"
	Go   PluginType = "go"
	Rust PluginType = "rust"
)

type MemoryGate struct {
	mu       sync.Mutex
	quotas   map[PluginType]int64 // in bytes
	usage    map[string]int64
}

func NewMemoryGate() *MemoryGate {
	fmt.Println("Memory Gate Initialized (Arxiv 2604.24579)")
	return &MemoryGate{
		quotas: map[PluginType]int64{
			Lua:  10 * 1024 * 1024, // 10MB
			Bun:  64 * 1024 * 1024, // 64MB
			Go:   32 * 1024 * 1024, // 32MB
			Rust: 16 * 1024 * 1024, // 16MB
		},
		usage: make(map[string]int64),
	}
}

func (mg *MemoryGate) RequestAllocation(pluginID string, pType PluginType, size int64) error {
	mg.mu.Lock()
	defer mg.mu.Unlock()

	quota := mg.quotas[pType]
	currentUsage := mg.usage[pluginID]

	if currentUsage+size > quota {
		return fmt.Errorf("memory quota exceeded for %s: limit %d bytes", pType, quota)
	}

	mg.usage[pluginID] += size
	fmt.Printf("Plugin %s (%s) allocated %d bytes. Total: %d\n", pluginID, pType, size, mg.usage[pluginID])
	return nil
}

func main() {
	gate := NewMemoryGate()
	err := gate.RequestAllocation("test-plugin-01", Lua, 1024)
	if err != nil {
		fmt.Println("Error:", err)
	}
}
