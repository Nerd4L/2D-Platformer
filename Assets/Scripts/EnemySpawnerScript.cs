using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using static Cinemachine.DocumentationSortingAttribute;

public class EnemySpawnerScript : MonoBehaviour
{
    private SpawnPointScript spawnPointScript;

    public string levelName;
    public Vector3[] spawnPoints;
    //public List<Vector3> spawnPoints;
    public GameObject[] enemyPrefabs;
    public static List<GameObject> spawnedEnemies = new List<GameObject>();

    // Start is called before the first frame update
    void Awake()
    {
        spawnPointScript = GameObject.FindGameObjectWithTag("EnemySpawner").GetComponent<SpawnPointScript>();
        levelName = SceneManager.GetActiveScene().name;

        spawnPoints = new Vector3[3];
        spawnPoints[0] = new Vector3(-31f, 1.6f, 0f);
        spawnPoints[1] = new Vector3(-29f, 1.6f, 0f);
        spawnPoints[2] = new Vector3(-20f, 0.6f, 0f);

        //spawnPoints = spawnPointScript.EnemyspawnPoints(levelName);
        SpawnEnemies(spawnPoints);
    }

    //private void SpawnEnemies(List<Vector3> levelSpawnPoints)
    private void SpawnEnemies(Vector3[] levelSpawnPoints)
    {
        for (int i = 0; i < levelSpawnPoints.Length; i++)
        {
            spawnedEnemies.Add(Instantiate(enemyPrefabs[0], levelSpawnPoints[i], transform.rotation));
        }
    }
}
