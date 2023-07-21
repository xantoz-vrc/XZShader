// idea by Nave, original: https://pastebin.com/Q43UPHf4
#if UNITY_EDITOR

using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class CreateParticlesMesh : MonoBehaviour
{
    // Change to what sizes you need
    private static readonly int[] sizes = { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024 };
    private static readonly int[] boundSizes = { 2, 3, 4, 5, 10 };

    [MenuItem("GameObject/Create Particles Triangle Mesh")]
    static void CreateTrianglesMesh()
    {
        foreach (int size in sizes) {
            var mesh = new Mesh();
            mesh.vertices = new Vector3[] { new Vector3(0, 0, 0) };
            mesh.triangles = new int[size * size * 3];
            mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1, 1, 1));
            string path = "Assets/XZShader/ParticleMeshes/Triangles" + size + "x" + size + ".asset";
            AssetDatabase.CreateAsset(mesh, path);
            EditorGUIUtility.PingObject(mesh);
        }
    }

    [MenuItem("GameObject/Create Particles Point Mesh")]
    static void CreatePointMesh()
    {
        foreach (int size in sizes) {
            var mesh = new Mesh();
            mesh.vertices = new Vector3[size];
            mesh.SetIndices(
                indices: new ushort[size],
                topology: MeshTopology.Points,
                submesh: 0,
                calculateBounds: false,
                baseVertex: 0);
            mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(1, 1, 1));
            string path = "Assets/XZShader/ParticleMeshes/Points" + size + ".asset";
            AssetDatabase.CreateAsset(mesh, path);
            EditorGUIUtility.PingObject(mesh);
        }
    }

    [MenuItem("GameObject/Create Particles Point Mesh with bounds")]
    static void CreatePointMesh2()
    {
        foreach (int b in boundSizes) {
            foreach (int size in sizes) {
                var mesh = new Mesh();
                mesh.vertices = new Vector3[size];
                mesh.SetIndices(
                    indices: new ushort[size],
                    topology: MeshTopology.Points,
                    submesh: 0,
                    calculateBounds: false,
                    baseVertex: 0);
                mesh.bounds = new Bounds(new Vector3(0, 0, 0), new Vector3(b, b, b));
                string path = "Assets/XZShader/ParticleMeshes/Points" + size + "-b" + b + "m.asset";
                AssetDatabase.CreateAsset(mesh, path);
                EditorGUIUtility.PingObject(mesh);
            }
        }
    }
}

#endif
