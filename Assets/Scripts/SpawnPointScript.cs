using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices.WindowsRuntime;
using Unity.VisualScripting;
using UnityEngine;

public class SpawnPointScript : MonoBehaviour
{
    //private Vector3[] spawnPoints;
    private List<GameObject> spawnPoints;
    public EnemyConstructor enemyConstructor;

    //public List<Vector3> EnemyspawnPoints(string levelName)
    //{
    //    spawnPoints = new List<GameObject>();
    //    //spawnPoints = new();

    //    switch (levelName)
    //    {
    //        case "Green Greens Level 1":
    //            //spawnPoints.Add(new enemyConstructor.WaddleDee(new Vector3(-32f, 1.6f, 0f), true));
    //            //spawnPoints.Add(new Vector3(-29f, 1.6f, 0f));
    //            //spawnPoints.Add(new Vector3(-20f, 0.6f, 0f));
    //            break;
    //        case "Green Greens Level 2":
    //            //spawnPoints.Add(new Vector3(-32f, 1.6f, 0f));
    //            //spawnPoints.Add(new Vector3(-29f, 1.6f, 0f));
    //            //spawnPoints.Add(new Vector3(-20f, 0.6f, 0f));
    //            break;
    //        default:
    //            break;
    //    }

    //    //return spawnPoints;
    //}
    
}
