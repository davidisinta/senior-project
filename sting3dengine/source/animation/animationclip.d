/// AnimationClip: keyframe data for one animation (e.g. "fire", "reload")
/// Loaded from a separate FBX file that contains only animation data.
/// Each clip has multiple channels — one per bone — with position,
/// rotation, and scale keyframes.
module animationclip;

import std.stdio;
import std.string : fromStringz;
import assimp_c_api;
import linear;

struct VectorKey
{
    double time;
    vec3 value;
}

struct QuatKey
{
    double time;
    float w, x, y, z;
}

struct BoneChannel
{
    string boneName;
    VectorKey[] positionKeys;
    QuatKey[] rotationKeys;
    VectorKey[] scaleKeys;
}

struct AnimationClip
{
    string name;
    double duration;
    double ticksPerSecond;
    BoneChannel[] channels;
    int[string] channelByBone;  // bone name → channel index

    /// Load animation clip from an FBX file.
    /// The FBX should contain only animation data (no meshes).
    void loadFromFile(string path, string clipName)
    {
        import std.string : toStringz;

        auto scene = aiImportFile(path.toStringz,
            aiProcess_Triangulate | aiProcess_GenNormals | aiProcess_FlipUVs);

        if (scene is null)
        {
            writeln("[clip] ERROR: failed to load ", path);
            return;
        }

        if (scene.mNumAnimations == 0)
        {
            writeln("[clip] ERROR: no animations in ", path);
            aiReleaseImport(scene);
            return;
        }

        auto anim = scene.mAnimations[0];
        name = clipName;
        duration = anim.mDuration;
        ticksPerSecond = anim.mTicksPerSecond > 0 ? anim.mTicksPerSecond : 30.0;

        channels.length = anim.mNumChannels;

        for (uint i = 0; i < anim.mNumChannels; i++)
        {
            auto ch = anim.mChannels[i];
            BoneChannel bc;
            bc.boneName = cast(string)ch.mNodeName.data[0 .. ch.mNodeName.length].dup;

            // Position keys
            bc.positionKeys.length = ch.mNumPositionKeys;
            for (uint k = 0; k < ch.mNumPositionKeys; k++)
            {
                bc.positionKeys[k].time = ch.mPositionKeys[k].mTime;
                bc.positionKeys[k].value = vec3(
                    ch.mPositionKeys[k].mValue.x,
                    ch.mPositionKeys[k].mValue.y,
                    ch.mPositionKeys[k].mValue.z);
            }

            // Rotation keys
            bc.rotationKeys.length = ch.mNumRotationKeys;
            for (uint k = 0; k < ch.mNumRotationKeys; k++)
            {
                bc.rotationKeys[k].time = ch.mRotationKeys[k].mTime;
                bc.rotationKeys[k].w = ch.mRotationKeys[k].mValue.w;
                bc.rotationKeys[k].x = ch.mRotationKeys[k].mValue.x;
                bc.rotationKeys[k].y = ch.mRotationKeys[k].mValue.y;
                bc.rotationKeys[k].z = ch.mRotationKeys[k].mValue.z;
            }

            // Scale keys
            bc.scaleKeys.length = ch.mNumScalingKeys;
            for (uint k = 0; k < ch.mNumScalingKeys; k++)
            {
                bc.scaleKeys[k].time = ch.mScalingKeys[k].mTime;
                bc.scaleKeys[k].value = vec3(
                    ch.mScalingKeys[k].mValue.x,
                    ch.mScalingKeys[k].mValue.y,
                    ch.mScalingKeys[k].mValue.z);
            }

            channels[i] = bc;
            channelByBone[bc.boneName] = cast(int)i;
        }

        aiReleaseImport(scene);

        writeln("[clip] loaded '", name, "' from ", path,
                " duration=", duration, " ticks/s=", ticksPerSecond,
                " channels=", channels.length);
    }

    /// Get the channel for a specific bone, or null if not found
    BoneChannel* getChannel(string boneName)
    {
        if (auto idx = boneName in channelByBone)
            return &channels[*idx];
        return null;
    }

    /// Duration in seconds
    double durationSeconds()
    {
        return duration / ticksPerSecond;
    }

    /// Print summary for debugging
    void printSummary()
    {
        writeln("=== CLIP: ", name, " ===");
        writeln("  Duration: ", duration, " ticks (", durationSeconds(), " sec)");
        writeln("  Ticks/sec: ", ticksPerSecond);
        writeln("  Channels: ", channels.length);
        for (uint i = 0; i < channels.length && i < 5; i++)
        {
            writeln("    [", i, "] '", channels[i].boneName,
                    "' pos=", channels[i].positionKeys.length,
                    " rot=", channels[i].rotationKeys.length,
                    " scale=", channels[i].scaleKeys.length);
        }
        if (channels.length > 5)
            writeln("    ... and ", channels.length - 5, " more");
        writeln("======================");
    }
}
