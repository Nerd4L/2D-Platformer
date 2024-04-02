using JetBrains.Annotations;
using System;
using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using Unity.VisualScripting;
using UnityEditor.Compilation;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;

public class ControllerScript : MonoBehaviour
{
    private Rigidbody2D kirbyBody;

    public Vector2 moveInput;
    
    const float groundedRadius = .3f;                                           // Distance of the overlap to determine if grounded
    private Vector3 velocity = Vector3.zero;

    private bool facingRight = true;                                            // For determining which way the player is currently facing.

    public float blinkInterval = 5f;
    public float blinkTimer = 0f;

    private bool allowedToDoubleJump = false;
    //private bool hasDoubleJumped = false;
    [SerializeField] private bool hasLetGoJump = false;

    [SerializeField] private Transform groundCheck;
    [SerializeField] private LayerMask whatIsGround;
    [SerializeField] private bool grounded;                                     // Whether or not the player is grounded                                  // Whether or not the player is on a platform
    [Range(0, .3f)][SerializeField] private float movementSmoothing = .1f;      // How much to smooth out the movement

    [Header("Events")]
    [Space]

    public UnityEvent OnFallingEvent;
    public UnityEvent OnGroundedEvent;
    public UnityEvent OnBlinkEvent;
    public UnityEvent OnJumpEvent;

    [System.Serializable]
    public class BoolEvent : UnityEvent<bool> { }

    private void Awake()
    {
        kirbyBody = GetComponent<Rigidbody2D>();

        OnFallingEvent ??= new UnityEvent();
        OnGroundedEvent ??= new UnityEvent();
        OnBlinkEvent ??= new UnityEvent();
        OnJumpEvent ??= new UnityEvent();

    }

    private void FixedUpdate()
    {
        grounded = false;

        // The player is grounded if a circlecast to the groundcheck position hits anything designated as ground
        // This can be done using layers instead but Sample Assets will not overwrite your project settings.
        Collider2D[] colliders = Physics2D.OverlapCircleAll(groundCheck.position, groundedRadius, whatIsGround);
        for (int i = 0; i < colliders.Length; i++)
        {
            if (colliders[i].gameObject != gameObject)
            {
                // Grounded
                grounded = true;
                //hasLetGoJump = true;
                OnGroundedEvent.Invoke();
                allowedToDoubleJump = true;

                // Blink
                blinkTimer += Time.deltaTime;
                float blinkValue = Mathf.Floor(blinkInterval * UnityEngine.Random.value);
                if (blinkTimer > blinkValue)
                {
                    OnBlinkEvent.Invoke();
                    blinkTimer = 0;
                }

                // TODO Tripping
            }
        }

        // Check if Falling
        if (kirbyBody.velocity.y < -0.01f)
        {
            OnFallingEvent.Invoke();
        }
    }

    public void Move(float move, bool jump, float jumpForce, bool dropDown)
    {
        // Move the character by finding the target velocity
        Vector3 targetVelocity = new Vector2(move * 10f, kirbyBody.velocity.y);
        // And then smoothing it out and applying it to the character
        kirbyBody.velocity = Vector3.SmoothDamp(kirbyBody.velocity, targetVelocity, ref velocity, movementSmoothing);

        // Flip the player
        if (move > 0 && !facingRight)
            Flip();
        else if (move < 0 && facingRight)
            Flip();

        if (dropDown || kirbyBody.velocity.y > 0f)
        {
            IgnorePlatforms(true);
        } 
        else if (!dropDown && !grounded)
        {
            IgnorePlatforms(false);
        }

        // If the player should jump...
        if (grounded && jump && Mathf.Abs(kirbyBody.velocity.y) < 0.01f)
        {
            Jump(jumpForce, false);
            OnJumpEvent.Invoke();
            //hasDoubleJumped = false;
        }
        else if (allowedToDoubleJump && jump && hasLetGoJump)
        {
            Jump(jumpForce, true);
            OnJumpEvent.Invoke();
            allowedToDoubleJump = false;
            //hasDoubleJumped = true;
        }
        if (!jump) {hasLetGoJump = true;} else {hasLetGoJump = false;}
    }

    private void IgnorePlatforms(bool active)
    {
        if (active)
        {
            Physics2D.IgnoreLayerCollision(3, 7, true);
        }
        else
        {
            Physics2D.IgnoreLayerCollision(3, 7, false);
        }
    }

    private void Flip()
    {
        // Rotate 180 on Y-axis
        if (facingRight)
        {
            Vector3 theRotation = new Vector3(transform.localRotation.x, 180f, transform.localRotation.z);
            transform.rotation = Quaternion.Euler(theRotation);
        }
        else
        {
            Vector3 theRotation = new Vector3(transform.localRotation.x, 0, transform.localRotation.z);
            transform.rotation = Quaternion.Euler(theRotation);
        }
        

        // Switch the way the player is labelled as facing.
        facingRight = !facingRight;
    }

    private void Jump(float addJumpForce, bool reset)
    {
        // Add a vertical force to the player.
        grounded = false;
        if (reset)
        {   
            Vector2 oldVector = kirbyBody.velocity; 
            kirbyBody.velocity = new Vector2(oldVector.x, 0f);
        }

        kirbyBody.AddForce(new Vector2(0f, addJumpForce));
    }
}
