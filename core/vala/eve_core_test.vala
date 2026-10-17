// Minimal compile + behavior check for AnterranianEveCore.vala (not shipped).
int main () {
    var ai = new AnterranianAI ();
    ai.generate_image ("phoenix sunrise");
    ai.create_music ("ember anthem", "Default");
    ai.create_duet ("duet");
    ai.npc_speak ("Welcome to Anterrania", "", "Welcome Guide");
    ai.propose_update ("brighter lava");
    assert (ai.core_cell.entry_count () == 5);
    assert (ai.core_cell.memory_log.get (3).has_prefix ("Welcome Guide spoke | Loc:Game_World"));
    assert (ai.core_cell.memory_log.get (1).contains ("Voice:Phoenix_Default_Voice"));
    assert (ai.core_cell.last_update_time > 0);
    ai.core_cell.lock_cell ();
    ai.generate_video ("ignored while locked");
    assert (ai.core_cell.entry_count () == 5);
    assert (!ai.core_cell.is_authenticated ());
    print ("eve_core_test OK: %d entries\n", ai.core_cell.entry_count ());
    return 0;
}
