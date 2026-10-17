// ANTERRANIAN EVE CORE - v2 (Phoenix, Oct 17 2026), cleaned for compilation.
// Source: docs/vala_reference/AnterranianEveCore_v2.vala (Foxy's branch feature/eve-core-v2) + /workspace/artifacts.
// Changes vs reference: lock_cell() (avoids clashing with Vala's `lock` statement keyword),
// last_update_time is int64 (GLib.get_real_time() returns microseconds as int64),
// accessors for the log, and a get_entries() helper. "nft hash" is just an id string, not a token.
// Reference implementation only: the shipping game uses scripts/ai/eve_core.gd (GDScript port).
// Compile check: valac --pkg gee-0.8 core/vala/AnterranianEveCore.vala core/vala/eve_core_test.vala -o /tmp/eve_core_test
using GLib;
using Gee;

public class BrainCell {
    public uint64 id;
    public string memory_nft_hash;
    public int64 last_update_time = 0;
    public Gee.ArrayList<string> memory_log = new Gee.ArrayList<string>();
    private bool locked = true;

    public BrainCell(uint64 cell_id) {
        id = cell_id;
        memory_nft_hash = "ANTERRANIAN-BRAIN-NFT-" + cell_id.to_string();
    }

    public void store_memory(string event, string location = "Core", string state = "Active", 
                             string content = "", string voice = "Phoenix_Default_Voice") {
        if (locked) return;
        string entry = @"$event | Loc:$location | State:$state | Voice:$voice | Content:$content";
        memory_log.add(entry);
        last_update_time = get_real_time();
    }

    public void unlock() { locked = false; }
    public void lock_cell() { locked = true; }
    public bool is_authenticated() { return !locked; }
    public int entry_count() { return memory_log.size; }
    public string last_entry() { return memory_log.size > 0 ? memory_log.get(memory_log.size - 1) : ""; }
}

public class AnterranianAI {
    public BrainCell core_cell;

    public AnterranianAI() {
        core_cell = new BrainCell(1);
        core_cell.unlock();
    }

    public void generate_image(string prompt) {
        core_cell.store_memory("Image Generated", "Visual_Core", "Creative", prompt);
    }

    public void generate_video(string prompt) {
        core_cell.store_memory("Video Generated", "Visual_Core", "Cinematic", prompt);
    }

    public void create_music(string prompt, string voice_profile = "Phoenix_Default_Voice") {
        string voice = (voice_profile == "Default" || voice_profile == "") ? "Phoenix_Default_Voice" : voice_profile;
        core_cell.store_memory("Music Created", "Music_Core", "Creative", prompt, voice);
    }

    public void create_duet(string prompt, string voice1 = "Phoenix_Default_Voice", string voice2 = "Phoenix_Companion_Voice") {
        core_cell.store_memory("Duet Created", "Music_Core", "Creative", prompt, voice1 + " + " + voice2);
    }

    public void output_audio(string content, string voice_profile = "Phoenix_Default_Voice", string output_mode = "Both") {
        string voice = (voice_profile == "Default" || voice_profile == "") ? "Phoenix_Default_Voice" : voice_profile;
        core_cell.store_memory("Audio Output", "Audio_Core", "Active", content, voice);
    }

    public void output_video(string content, string voice_profile = "Phoenix_Default_Voice") {
        string voice = (voice_profile == "Default" || voice_profile == "") ? "Phoenix_Default_Voice" : voice_profile;
        core_cell.store_memory("Video Output", "Visual_Core", "Active", content, voice);
    }

    public void npc_speak(string dialogue, string voice_profile = "Phoenix_Default_Voice", string npc_name = "NPC") {
        string voice = (voice_profile == "Default" || voice_profile == "") ? "Phoenix_Default_Voice" : voice_profile;
        core_cell.store_memory(npc_name + " spoke", "Game_World", "Active", dialogue, voice);
    }

    public void propose_update(string change_description) {
        core_cell.store_memory("Update Proposed", "Core", "PendingApproval", change_description);
    }
}
